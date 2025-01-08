rm latest.dump
heroku login -i
heroku pg:backups:capture -a spinal
heroku pg:backups:download -a spinal
pg_restore --verbose --clean --no-acl --no-owner -h localhost -d spinal_care_ror_development latest.dump

