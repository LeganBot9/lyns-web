-- ============================================================================
-- Migration 3 — run ONCE in the SQL editor. Keeps your data.
--
-- Adds a photo/logo to organiser profiles, shown to you in the review queue
-- when you approve an organiser.
-- ============================================================================

alter table public.organisers add column if not exists logo_url text;
