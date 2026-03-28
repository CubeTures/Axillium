package models

import "gorm.io/gorm"

type Post struct {
	gorm.Model
	AuthorID      uint   `json:"author_id"`
	AuthorAlias   string `json:"author_alias"`
	AddictionType string `json:"addiction_type"`
	Title         string `json:"title"`
	Content       string `json:"content"`
	Status        string `json:"status"`       // "pending_review" | "published"
	Featured      bool   `json:"featured"`
	FeaturedWeek  string `json:"featured_week"` // ISO week e.g. "2026-W13"
}
