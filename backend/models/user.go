package models

import (
	"time"

	"gorm.io/gorm"
)

type User struct {
	gorm.Model
	PhoneNumber            string     `gorm:"uniqueIndex" json:"-"` // never exposed in responses
	Password               string     `json:"-"`                    // bcrypt hash, never exposed
	Alias                  string     `json:"alias"`
	GroupID                uint       `json:"group_id"`
	Role                   string     `json:"role"`         // apprentice, sponsor, leader, influencer, graduated
	SponsorID              uint       `json:"sponsor_id"`   // ID of this user's sponsor (0 = none)
	IsAvailable            bool       `json:"is_available"` // for sponsors: whether accepting new apprentices
	OriginalRole           string     `json:"original_role"`            // role before demotion; "" = not demoted
	SponsorProgressResetAt *time.Time `json:"sponsor_progress_reset_at"` // nil = no reset; set on 3rd relapse
}

type AuthResponse struct {
	ID        uint   `json:"id"`
	Alias     string `json:"alias"`
	GroupID   uint   `json:"group_id"`
	Role      string `json:"role"`
	SponsorID uint   `json:"sponsor_id"`
}
