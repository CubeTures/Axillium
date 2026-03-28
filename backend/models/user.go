package models

import "gorm.io/gorm"

type User struct {
	gorm.Model
	PhoneNumber string `gorm:"uniqueIndex" json:"-"` // never exposed in responses
	Password    string `json:"-"`                    // bcrypt hash, never exposed
	Alias       string `json:"alias"`
	GroupID     uint   `json:"group_id"`
	Role        string `json:"role"`         // apprentice, sponsor, leader, influencer, graduated
	SponsorID   uint   `json:"sponsor_id"`   // ID of this user's sponsor (0 = none)
	IsAvailable bool   `json:"is_available"` // for sponsors: whether accepting new apprentices
}

type AuthResponse struct {
	ID        uint   `json:"id"`
	Alias     string `json:"alias"`
	GroupID   uint   `json:"group_id"`
	Role      string `json:"role"`
	SponsorID uint   `json:"sponsor_id"`
}
