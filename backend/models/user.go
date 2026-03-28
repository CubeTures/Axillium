package models

import "gorm.io/gorm"

type User struct {
	gorm.Model
	PhoneNumber string `gorm:"uniqueIndex" json:"-"` // never exposed in responses
	Password    string `json:"-"`                    // bcrypt hash, never exposed
	Alias       string `json:"alias"`
}

type AuthResponse struct {
	ID    uint   `json:"id"`
	Alias string `json:"alias"`
}
