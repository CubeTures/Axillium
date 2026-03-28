package models

import "gorm.io/gorm"

type Group struct {
	gorm.Model
	Name          string `json:"name"`
	AddictionType string `json:"addiction_type"`
	Location      string `json:"location"`
	LeaderID      uint   `json:"leader_id"` // 0 = no leader yet
}
