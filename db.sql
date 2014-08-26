create schema tenant1;
set search_path to tenant1;

create table movies (
  id int,
  title text
);

create table licenses (
  id int,
  title text, 
  start_date timestamp, 
  end_date timestamp
);

-- Create audit triggers
create or replace function create_triggers() returns void
language plpgsql AS $$
declare
  tables record;
  mode record;
  cols record;

  trigger_name text;
  proc_name text;
  table_name text;

  table_sql text;
  procedure_sql text;
  drop_trigger_sql text;
  trigger_sql text;

  type text;

  columns_list text;
  columns_type text;
  columns_insert text;
begin
  for tables in 
    select * 
    from information_schema.tables t
    where t.table_name not like '%$a' 
      and t.table_schema = current_schema
  loop
    columns_list := '';
    columns_type := '';
    columns_insert := '';  
  
    for cols in
      select * 
      from information_schema.columns c
      where c.table_name not like '%$a'
        and c.table_name = tables.table_name
        and c.table_schema = tables.table_schema
      order by ordinal_position
    loop     
      type := cols.data_type;   
      
      columns_list := cols.column_name || ', ';
      columns_insert := '$1.' || cols.column_name || ', ';
      columns_type := cols.column_name || ' ' || type || ', ';
    end loop;

    columns_list := 
      substring(
        columns_list 
        from 0 
        for length(columns_list) - 1);

    columns_insert := 
      substring(
        columns_insert 
        from 0 
        for length(columns_insert) - 1);
        
    columns_type := 
      substring(
        columns_type 
        from 0 
        for length(columns_type) - 1);

    table_name = current_schema || '.' || format('%I', tables.table_name);

    -- oddly this style of table creation does not allow 'if not exists'
    table_sql := 
      format(
       'create table %s$a
        as select t.*, 
             null::varchar(1) audit_action,
             null::varchar audit_context, 
             null::timestamp audit_date
           from %s t 
           where 0 = 1',
       table_name,
       table_name
    );
 
    raise notice '%', table_sql;
    execute table_sql;

    for mode in 
      select unnest(array['insert', 'update', 'delete']) op,
             unnest(array['new', 'new', 'old']) target,
             unnest(array['I', 'U', 'D']) "value"
    loop
      proc_name :=
         current_schema || '.' || format('%I', 'audit_' || mode.op || '_' || tables.table_name);

      procedure_sql := 
        format(
          e'create or replace function %s() returns trigger
            language plpgsql AS $fn$
            declare
              context text;
            begin
              select application_name from pg_stat_activity where pid = pg_backend_pid() INTO context;

              execute 
                ''insert into %I$a 
                    (%s, audit_action, audit_context, audit_date)
                  values
                    (%s, $2, $3, $4)''
                  using %s, ''%s'', context, now();

               return %I;
            end;
            $fn$;',
          proc_name,
          tables.table_name,
          columns_list,
          columns_insert,
          mode.target,
          mode.value,
          mode.target);

      trigger_name := format('%I', tables.table_name || '_' || mode.op || '$t');
      drop_trigger_sql := 'drop trigger if exists ' || trigger_name || ' on ' || table_name;
    
      trigger_sql :=
        format(
          'create trigger %s
             after %s on %s
           for each row execute procedure %s();',
          trigger_name,
          mode.op,
          table_name,
          proc_name
        );

      raise notice '%', procedure_sql;
      execute procedure_sql;

      raise notice '%', drop_trigger_sql;
      execute drop_trigger_sql;
        
      raise notice '%', trigger_sql;    
      execute trigger_sql;
    end loop;
  end loop;
end;
$$;

-- Queries to test creation of triggers
drop table tenant1.movies$a cascade;
drop table tenant1.licenses$a cascade;

select create_triggers();

select * 
from information_schema.tables
where 1=1 --table_name like '%$a%' 
and table_schema = current_schema

select * from movies;
insert into movies(id, title) values (1, 'Star Wars');
update movies set id = 2;
delete from movies;
select * from tenant1.movies$a;

-- Create data...

-- Test queries

SELECT application_name 
FROM pg_stat_activity 
WHERE procpid = pg_backend_pid() 
INTO v_context;


-- Blame query
SELECT * FROM (
  SELECT audit_user, test
  FROM movies$a
  WHERE id = ...
  ORDER BY audit_date DESC
) LIMIT 1


-- Range test
select
  id, title
from
  movies_vw
where 
  license_effective @> now()

-- Range view
  CREATE view movie_ranges AS 
  SELECT
    tsrange(
      s.audit_date, 
      coalesce(lead(s.audit_date) 
                 over(
                   partition by s.i_id 
                   order by s.audit_date), 
               'infinity'), 
               '[)'
    ) m_effective,
    m.audit_date
    movie.name,
  FROM movie$a s

-- Range view 2
CREATE view movie_ranges AS 
  SELECT
    tsrange(
      s.audit_date, 
      coalesce(lead(s.audit_date) 
                 over(
                   partition by s.i_id 
                   order by s.audit_date), 
               'infinity'), 
               '[)'
    ) m_effective,
    m.audit_date
    movie.name,
  FROM movie$a s

-- Range view 3
WITH s as (
  SELECT
    *
  FROM movie_vw s
  LEFT JOIN (
    license_vw 
  ) l ON l.name = m.licensee
),
all_joined as (
  SELECT
    -- anything not found in a left join gets turned into an infinite range
    coalesce(mis_effective, tsrange('-infinity', 'infinity', '[]')) mis_effective,
    coalesce(mir_effective, tsrange('-infinity', 'infinity', '[]')) mir_effective,
    greatest(s._audit_date_, r._audit_date_) _audit_date_,
    s.tmf_level
  FROM s
  LEFT JOIN r ON s.id = r.id
)
select *
from all_joined
where ...


-- Blame with timestamp
SELECT movie_user, license_user, test
FROM movies_vw
WHERE id = ...
AND date_range <@ '12345'


