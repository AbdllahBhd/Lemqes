-- Runs last (files run in name order): drops the tests schema 000-setup.sql created, so its
-- definer helpers (freeze_now redefines public.live_now, set_hours writes pro_hours) do not stay
-- in the database between runs. No begin/rollback: the drop must persist.
set client_min_messages = warning;
select plan(1);
select ok(true, 'teardown: the tests schema is dropped after the suite');
drop schema tests cascade;
select * from finish();
