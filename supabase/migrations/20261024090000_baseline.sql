-- =====================================================================
-- BASELINE database ONLINE (Supabase / PostgreSQL) - Gerak In (FitMate)
-- BASELINE: mencerminkan kondisi database yang SUDAH ADA di Supabase.
-- Jangan dijalankan ulang di database yang sama; tandai dengan
-- `supabase migration repair <nomor> --status applied`.
-- =====================================================================
-- Catatan desain:
-- 1. Semua id memakai UUID. Untuk data yang dibuat saat offline
--    (activities, daily_targets, schedules), UUID dibuat di aplikasi
--    sehingga sinkronisasi ke server aman dari data ganda.
-- 2. Waktu disimpan dalam UTC (timestamptz). Konversi WIB/WITA/WIT/London
--    dilakukan di aplikasi saat ditampilkan.
-- 3. Login memakai tabel users sendiri (password di-hash bcrypt oleh
--    Edge Function), bukan Firebase.
-- 4. Target akhirnya RLS aktif di semua tabel TANPA policy, supaya kunci anon di
--    aplikasi tidak bisa membaca tabel langsung (semua akses lewat Edge Function).
--    Baseline ini mencatat kondisi saat ini: 7 tabel belum ber-RLS. Migration
--    berikutnya (security_fix) mengaktifkannya.
-- 5. Skor game TIDAK disimpan di server (hanya SQLite lokal, tabel quiz_scores).
-- 6. Foto profil dan gambar postingan disimpan di Supabase Storage (bucket
--    dibuat di bagian STORAGE di bawah); kolom photo_url/image_url berisi URL-nya.
-- =====================================================================


-- ---------- AKUN & PROFIL (Sprint 1, 5) ----------

create table users (
  id            uuid primary key default gen_random_uuid(),
  username      text not null unique,
  email         text not null unique,
  password_hash text not null,
  full_name     text,
  photo_url     text,                   -- URL gambar di Supabase Storage
  height_cm     numeric(5,1),           -- untuk estimasi kalori
  weight_kg     numeric(5,1),
  goal          text,                   -- mis. 'turun berat badan', 'tambah otot'
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  auth_user_id  uuid references auth.users(id)   -- sisa rancangan Supabase Auth, tidak dipakai login kita
);

-- Saran & kesan mata kuliah (Profile)
create table feedback (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  saran      text,
  kesan      text,
  created_at timestamptz not null default now()
);


-- ---------- DATA MASTER OLAHRAGA (Sprint 3, 7) ----------

create table sports (
  id            bigint generated always as identity primary key,
  name          text not null,
  category      text not null,          -- mis. 'kardio', 'kekuatan', 'fleksibilitas'
  difficulty    text not null default 'pemula'
                check (difficulty in ('pemula','menengah','lanjut')),
  kcal_per_min  numeric(5,2) not null default 5,
  description   text,
  video_url     text,                   -- tautan YouTube
  is_premium    boolean not null default false,
  created_at    timestamptz not null default now(),
  body_part     text                    -- bagian tubuh yang dilatih
);


-- ---------- AKTIVITAS, TARGET, JADWAL (Sprint 3, 4, 8, 10, 12) ----------
-- Tiga tabel ini punya kembaran di SQLite agar bisa dipakai offline.
-- updated_at dipakai untuk menyelesaikan konflik (data terbaru menang),
-- deleted_at dipakai sebagai penanda hapus agar penghapusan ikut tersinkron.

create table activities (
  id           uuid primary key,        -- dibuat di aplikasi
  user_id      uuid not null references users(id) on delete cascade,
  sport_id     bigint references sports(id),
  started_at   timestamptz not null,
  ended_at     timestamptz,
  duration_sec integer not null default 0,
  steps        integer not null default 0,
  distance_m   numeric(10,2) not null default 0,
  calories     numeric(8,2) not null default 0,
  reps         integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);

-- Satu baris per pengguna. Kuncinya user_id (bukan UUID acak) supaya login di
-- dua perangkat tidak menghasilkan dua target. Sinkronisasi memakai upsert
-- berdasarkan user_id.
create table daily_targets (
  user_id      uuid primary key references users(id) on delete cascade,
  steps        integer not null default 6000,
  duration_min integer not null default 30,
  calories     integer not null default 300,
  updated_at   timestamptz not null default now()
);

create table schedules (
  id            uuid primary key,       -- dibuat di aplikasi
  user_id       uuid not null references users(id) on delete cascade,
  sport_id      bigint references sports(id),
  title         text not null,
  scheduled_at  timestamptz not null,   -- disimpan UTC
  duration_min  integer not null default 30,
  timezone      text not null default 'Asia/Jakarta',  -- zona yang dipilih pengguna
  remind        boolean not null default true,
  is_done       boolean not null default false,
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index idx_activities_user_time on activities (user_id, started_at desc);
create index idx_schedules_user_time  on schedules  (user_id, scheduled_at);


-- ---------- KOMUNITAS (Sprint 17) ----------
-- Hanya di server karena sifatnya interaksi antar pengguna.

create table posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  content    text not null,
  image_url  text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table post_likes (
  post_id    uuid not null references posts(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)        -- satu pengguna satu like per postingan
);

create table post_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references posts(id) on delete cascade,
  user_id    uuid not null references users(id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default now()
);

create table post_reports (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references posts(id) on delete cascade,
  reporter_id uuid not null references users(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now()
);

create index idx_posts_created on posts (created_at desc);
create index idx_comments_post on post_comments (post_id, created_at);


-- ---------- ACHIEVEMENT BLOCKCHAIN (Sprint 18) ----------

-- Daftar achievement yang tersedia (sebagian ditandai premium)
create table achievements (
  code        text primary key,         -- mis. 'STREAK_7', 'BEST_REPS_PUSHUP'
  name        text not null,
  description text,
  is_premium  boolean not null default false
);

-- Rantai blok per pengguna
create table achievement_blocks (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references users(id) on delete cascade,
  block_index   integer not null,       -- 0 = blok pertama (genesis)
  timestamp     timestamptz not null default now(),
  achievement_code text references achievements(code),
  data          jsonb not null default '{}'::jsonb,  -- mis. {"reps": 42}
  previous_hash text not null,
  hash          text not null,          -- SHA-256 dari isi blok
  unique (user_id, block_index)
);


-- ---------- PREMIUM & PEMBAYARAN SIMULASI (Sprint 19) ----------

create table subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  plan       text not null default 'plus',
  status     text not null default 'active'
             check (status in ('active','expired','cancelled')),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null
);

-- Catatan pembayaran simulasi (tidak ada uang sungguhan)
create table payments (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  subscription_id uuid references subscriptions(id),
  currency     text not null check (currency in ('IDR','USD','EUR')),
  amount       numeric(12,2) not null,   -- jumlah dalam mata uang yang dipilih
  rate_to_idr  numeric(14,4) not null,   -- kurs yang dipakai saat bayar
  status       text not null default 'success',
  created_at   timestamptz not null default now()
);

create index idx_subs_user on subscriptions (user_id, expires_at desc);


-- ---------- TAMBAHAN DARI TIM (sudah ada di database) ----------

-- Pencatatan pemakaian chatbot (untuk batas pemakaian / rate limit, PBI-15.7).
-- Catatan: bentuk kolom id (identity) adalah perkiraan; tidak berpengaruh pada
-- database yang sudah ada karena baseline ini tidak dijalankan ulang.
create table chat_usage (
  id         bigint generated always as identity primary key,
  user_id    text not null,
  created_at timestamptz not null default now()
);
create index chat_usage_user_time_idx on chat_usage (user_id, created_at desc);

-- Fitur ikuti pengguna (Community). Kondisi saat ini: mengacu ke auth.users
-- (Supabase Auth), padahal akun kita ada di public.users. Diperbaiki di
-- migration security_fix.
create table user_follows (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamp not null default now(),
  followers_id uuid references auth.users(id),
  following_id uuid references auth.users(id)
);


-- ---------- BIAYA GYM UNTUK MAPS (Sprint 11, PBI-11.9) ----------
-- Data demo biaya beberapa gym. osm_id dicocokkan dengan hasil Overpass API
-- (format 'node/123456789' atau 'way/123456789'). Biaya disimpan dalam IDR;
-- konversi ke USD dan EUR dilakukan di aplikasi memakai kurs.
-- Tempat yang tidak ada di tabel ini tidak menampilkan kalkulator biaya.

create table gym_fees (
  osm_id      text primary key,
  name        text not null,
  fee_idr     integer not null check (fee_idr >= 0),
  fee_period  text not null default 'per_bulan'
              check (fee_period in ('per_bulan','per_kunjungan')),
  note        text,
  updated_at  timestamptz not null default now()
);


-- ---------- STORAGE: foto profil dan gambar postingan ----------
-- Bucket publik supaya gambar bisa ditampilkan lewat URL. Upload tetap
-- dilakukan lewat Edge Function (service role), bukan langsung dari aplikasi.

insert into storage.buckets (id, name, public) values
  ('avatars',     'avatars',     true),
  ('post-images', 'post-images', true)
on conflict (id) do nothing;


-- ---------- KEAMANAN: RLS (kondisi saat ini) ----------
-- Belum ber-RLS: posts, post_comments, post_likes, post_reports, sports,
-- activities, user_follows (diperbaiki di migration security_fix).

alter table users enable row level security;
alter table feedback enable row level security;
alter table daily_targets enable row level security;
alter table schedules enable row level security;
alter table achievements enable row level security;
alter table achievement_blocks enable row level security;
alter table subscriptions enable row level security;
alter table payments enable row level security;
alter table gym_fees enable row level security;
alter table chat_usage enable row level security;


-- ---------- DATA AWAL (contoh, silakan diubah) ----------
-- video_url diisi sendiri dengan tautan YouTube pilihan kelompok.

insert into sports (name, category, difficulty, kcal_per_min, is_premium) values
  ('Push-up',         'kekuatan',      'pemula',   7.0, false),
  ('Squat',           'kekuatan',      'pemula',   6.0, false),
  ('Jumping Jack',    'kardio',        'pemula',   8.0, false),
  ('Plank',           'kekuatan',      'pemula',   4.0, false),
  ('Lari di Tempat',  'kardio',        'pemula',   9.0, false),
  ('Burpee',          'kardio',        'lanjut',  11.0, true),
  ('Mountain Climber','kardio',        'menengah', 9.5, true),
  ('Yoga Dasar',      'fleksibilitas', 'pemula',   3.0, true);

insert into achievements (code, name, description, is_premium) values
  ('FIRST_WORKOUT', 'Langkah Pertama',  'Menyelesaikan latihan pertama',        false),
  ('TARGET_DAY',    'Target Tercapai',  'Mencapai target harian',               false),
  ('STREAK_7',      'Konsisten 7 Hari', 'Berolahraga 7 hari berturut-turut',    false),
  ('STEPS_100K',    'Seratus Ribu',     'Total 100.000 langkah',                true),
  ('BEST_REPS',     'Repetisi Terbaik', 'Rekor repetisi tertinggi dalam sesi',  true);

-- Contoh data biaya gym. Ganti osm_id dengan ID asli dari hasil Overpass
-- (lihat id elemen pada respons API), lalu hapus tanda komentar.
-- insert into gym_fees (osm_id, name, fee_idr, fee_period, note) values
--   ('node/0000000001', 'Nama Gym Contoh 1', 250000, 'per_bulan',     'Termasuk loker'),
--   ('node/0000000002', 'Nama Gym Contoh 2',  30000, 'per_kunjungan', null);
