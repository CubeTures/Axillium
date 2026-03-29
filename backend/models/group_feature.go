package models

import "time"

type GroupFeature struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	PostID       uint      `json:"post_id"`
	GroupID      uint      `json:"group_id"`
	FeaturedByID uint      `json:"featured_by_id"`
	FeaturedWeek string    `json:"featured_week"`
	CreatedAt    time.Time `json:"created_at"`
}
