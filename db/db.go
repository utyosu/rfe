package db

import (
	"fmt"
	"github.com/utyosu/rfe/env"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	dbs *gorm.DB
)

func init() {
	var err error
	dsn := fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?parseTime=true",
		env.DbUser,
		env.DbPassword,
		env.DbHost,
		env.DbPort,
		env.DbName,
	)

	logLevel := logger.Warn
	switch env.DbLogLevel {
	case "silent":
		logLevel = logger.Silent
	case "error":
		logLevel = logger.Error
	case "info":
		logLevel = logger.Info
	}

	dbs, err = gorm.Open(
		mysql.Open(dsn),
		&gorm.Config{
			Logger: logger.Default.LogMode(logLevel),
		},
	)

	if err != nil {
		panic(err)
	}
}
