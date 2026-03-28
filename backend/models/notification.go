package models

import "gorm.io/gorm"

type Notification struct {
	gorm.Model
	RecipientID uint   `json:"recipient_id"`
	SenderID    uint   `json:"sender_id"`
	Type        string `json:"type"`    // e.g. "relapse_alert"
	Message     string `json:"message"`
	Read        bool   `json:"read"`
}
