package models

import "gorm.io/gorm"

// WeeklyPrompt holds the single active prompt for a given ISO week.
// Only one row per iso_week (enforced by uniqueIndex).
type WeeklyPrompt struct {
	gorm.Model
	ISOWeek    string `gorm:"uniqueIndex" json:"iso_week"`
	PromptText string `json:"prompt_text"`
	SetByID    uint   `json:"set_by_id"`
	SetByAlias string `json:"set_by_alias"`
	SetByRole  string `json:"set_by_role"`
}

// PromptResponse is one user reply in the current week's discussion thread.
type PromptResponse struct {
	gorm.Model
	PromptID  uint   `json:"prompt_id"`
	UserID    uint   `json:"user_id"`
	UserAlias string `json:"user_alias"`
	UserRole  string `json:"user_role"`
	Content   string `json:"content"`
}
