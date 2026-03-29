package models

import "gorm.io/gorm"

type DirectMessage struct {
	gorm.Model
	SenderID    uint   `json:"sender_id"`
	RecipientID uint   `json:"recipient_id"`
	SenderAlias string `json:"sender_alias"`
	SenderRole  string `json:"sender_role"`
	Content     string `json:"content"`
}
