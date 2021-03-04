package db

import (
	basic_errors "errors"
	"github.com/pkg/errors"
	"gorm.io/gorm"
)

type User struct {
	gorm.Model
	DiscordUserId int64
	Name          string
}

func FindUser(discordUserId int64) (*User, error) {
	user := User{}
	if err := dbs.Take(&user, "discord_user_id=?", discordUserId).Error; err != nil {
		if basic_errors.Is(err, gorm.ErrRecordNotFound) {
			return &user, nil
		}
		return nil, errors.WithStack(err)
	}
	return &user, nil
}

func FindOrCreateUser(discordUserId int64, name string) (*User, error) {
	user, err := FindUser(discordUserId)
	if err != nil {
		return nil, errors.WithStack(err)
	}
	if user.ID == 0 {
		user.DiscordUserId = discordUserId
		user.Name = name
		if err := dbs.Create(&user).Error; err != nil {
			return nil, errors.WithStack(err)
		}
	} else if user.Name != name {
		user.Name = name
		if err := dbs.Save(&user).Error; err != nil {
			return nil, errors.WithStack(err)
		}
	}
	return user, nil
}