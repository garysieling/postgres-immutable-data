
drop table license cascade;

create table license (
  id int primary key,
  company text, 
  effective_date tstzrange,
  audit_user text,
  audit_action text,
  audit_date tstzrange  
);

drop table movie;

create table movie (
  id int primary key,
  title text,
  license_owner int references license (id) not null,
  audit_user text,
  audit_action text,
  audit_date tstzrange
);

create or replace view movies as
select l.id license_id,
       l.company license_company,
       l.effective_date license_effective,
       l.audit_user license_audit_user,
       l.audit_date license_audit_range,
       m.id movie_id,
       m.title movie_title,
       m.audit_user movie_audit_user,
       m.audit_date movie_audit_date
from movie m
join license l on m.license_owner = l.id;
 

CREATE RULE movie_insert AS ON INSERT
TO movie
DO NOTHING;

CREATE RULE movie_delete AS ON DELETE
TO movie
DO NOTHING;

CREATE RULE movie_update AS ON UPDATE
TO movie
DO NOTHING;


CREATE RULE license_insert AS ON INSERT
TO license
DO NOTHING;

CREATE RULE license_delete AS ON DELETE
TO license
DO NOTHING;

CREATE RULE license_update AS ON UPDATE
TO license
DO NOTHING;

create sequence global_id;

CREATE RULE movies_add AS ON INSERT
TO movies
DO INSTEAD (
  WITH new_license AS (
    INSERT 
    INTO license
     (id, company, effective_date, audit_user, audit_action)
    VALUES
       (
          nextval('global_id'),
          NEW.license_company,
          NEW.license_effective,
          'gary',
          'I'
       )
    RETURNING id
  )
  INSERT
  INTO movie 
     (id, title, license_owner, audit_user, audit_action)
  SELECT nextval('global_id'),
         new.movie_title,
         new_license.id,
         'gary', 
         'I'
   FROM new_license
);

insert 
into movies (movie_title, license_company, license_effective) 
values ('Star Wars', 'Disney', '[2010-01-01 14:30, 2010-01-01 15:30)');


/*
INSERT INTO movies_audit VALUES (
  new.id,
  new.title,
  new.license_owner,
  new.license_effective,
  current_user,
  'U',
  now()  
);

insert into movies_audit
(id, title, license_owner, license_effective) 
values (1, 'Star Wars', 'Disney', tstzrange(now(), now()))
*/
