begin;
select plan(1);
select ok(tests.create_user('+213550000099') is not null);
select * from finish();
rollback;
