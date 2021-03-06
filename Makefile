TIMESTAMP := $(shell TZ='Asia/Tokyo' date '+%Y%m%d%H%M')
BACKUP_DIR := db/backups
BACKUP_FILE_PREFIX := dump_rfe_production_
LD_FLAGS := \
  -X 'github.com/utyosu/rfe/app.commitHash=$(shell git log --pretty=format:%H -n 1)' \
  -X 'github.com/utyosu/rfe/app.buildDatetime=$(shell TZ='Asia/Tokyo' date '+%Y-%m-%d %H:%M:%S JST')'

fmt:
	go fmt ./...

tidy:
	go mod tidy

build-local: fmt tidy
	go build -ldflags="${LD_FLAGS}" -o bin/rfe-local -tags="local"

build-production:
	GOOS=linux GOARCH=amd64 go build -ldflags="${LD_FLAGS}" -o bin/rfe-production -tags="production"

run-local: build-local
	sleep 0.5
	./bin/rfe-local

deploy-production: build-production
	scp bin/rfe-production production:/tmp
	ssh production " \
		mv /tmp/rfe-production /home/ec2-user && \
		supervisorctl restart rfe \
	"

start-production:
	ssh production "supervisorctl start rfe"

stop-production:
	ssh production "supervisorctl stop rfe"

reset-db-local:
	sudo mysql -e " \
		DROP DATABASE IF EXISTS ${RFE_DATABASE_NAME_LOCAL}; \
		CREATE DATABASE ${RFE_DATABASE_NAME_LOCAL}; \
	"
	@make migrate-db-up-local

migrate-db-up-local:
	migrate -path db/migrations -database "mysql://${RFE_DATABASE_USER_LOCAL}:@tcp(${RFE_DATABASE_HOST_LOCAL}:${RFE_DATABASE_PORT_LOCAL})/${RFE_DATABASE_NAME_LOCAL}" up
	mysqldump -u ${RFE_DATABASE_USER_LOCAL} -h ${RFE_DATABASE_HOST_LOCAL} -P ${RFE_DATABASE_PORT_LOCAL} ${RFE_DATABASE_NAME_LOCAL} -d --skip-comments --no-tablespaces > db/schema.sql

migrate-db-down-local:
	migrate -path db/migrations -database "mysql://${RFE_DATABASE_USER_LOCAL}:@tcp(${RFE_DATABASE_HOST_LOCAL}:${RFE_DATABASE_PORT_LOCAL})/${RFE_DATABASE_NAME_LOCAL}" down 1
	mysqldump -u ${RFE_DATABASE_USER_LOCAL} -h ${RFE_DATABASE_HOST_LOCAL} -P ${RFE_DATABASE_PORT_LOCAL} ${RFE_DATABASE_NAME_LOCAL} -d --skip-comments --no-tablespaces > db/schema.sql

migrate-db-production:
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	migrate -path db/migrations -database "mysql://${RFE_DATABASE_USER_PRODUCTION}:${RFE_DATABASE_PASSWORD_PRODUCTION}@tcp(${RFE_DATABASE_HOST_PRODUCTION}:${RFE_DATABASE_PORT_PRODUCTION})/${RFE_DATABASE_NAME_PRODUCTION}" up

backup-db-production:
	mkdir -p db/backups
	mysqldump -u ${RFE_DATABASE_USER_PRODUCTION} -h ${RFE_DATABASE_HOST_PRODUCTION} -P ${RFE_DATABASE_PORT_PRODUCTION} ${RFE_DATABASE_NAME_PRODUCTION} --skip-comments --no-tablespaces --set-gtid-purged=OFF --default-character-set=binary -p > ${BACKUP_DIR}/${BACKUP_FILE_PREFIX}$(TIMESTAMP).sql
	@echo "Create dump to ${BACKUP_DIR}/${BACKUP_FILE_PREFIX}$(TIMESTAMP).sql"
