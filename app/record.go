package app

import (
	"github.com/bwmarrin/discordgo"
	"github.com/pkg/errors"
	"github.com/utyosu/rfe/db"
	"github.com/utyosu/rfe/env"
	"strconv"
)

func recordServerActivities() {
	if err := recordServerActivitiesImpl(); err != nil {
		slackWarning.Post(err)
	}
}

func recordServerActivitiesImpl() error {
	guild, err := discordSession.State.Guild(env.RecordGuildId)
	if err != nil {
		return errors.WithStack(err)
	}

	// チャンネルの記録
	for _, c := range guild.Channels {
		if c.Type != discordgo.ChannelTypeGuildVoice {
			continue
		}
		channelId, err := strconv.ParseInt(c.ID, 10, 64)
		if err != nil {
			return errors.WithStack(err)
		}

		guildId, err := strconv.ParseInt(c.GuildID, 10, 64)
		if err != nil {
			return errors.WithStack(err)
		}

		if _, err := db.FindOrCreateChannel(channelId, guildId, c.Name); err != nil {
			return errors.WithStack(err)
		}
	}

	// 通話状況の記録
	for _, v := range guild.VoiceStates {
		discordUserId, err := strconv.ParseInt(v.UserID, 10, 64)
		if err != nil {
			return errors.WithStack(err)
		}

		discordChannelId, err := strconv.ParseInt(v.ChannelID, 10, 64)
		if err != nil {
			return errors.WithStack(err)
		}

		if err := db.InsertUserStatus(discordUserId, discordChannelId, int64(env.RecordInterval.Seconds())); err != nil {
			return errors.WithStack(err)
		}
	}

	return nil
}
