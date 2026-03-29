package models

import "gorm.io/gorm"

type CrisisAlert struct {
	gorm.Model
	UserID          uint   `json:"user_id"`
	UserAlias       string `json:"user_alias"`
	GroupID         uint   `json:"group_id"`
	Stage           int    `json:"stage"` // 1 = personal sponsor, 2 = group sponsors, 3 = community
	Resolved        bool   `json:"resolved"`
	ResolvedByID    uint   `json:"resolved_by_id"`
	ResolvedByAlias string `json:"resolved_by_alias"`
}
