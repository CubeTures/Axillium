package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type DMResponse struct {
	models.DirectMessage
	SenderProfilePicture string `json:"sender_profile_picture"`
}

func GetDMs(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userA, errA := strconv.ParseUint(c.Query("user_a"), 10, 64)
		userB, errB := strconv.ParseUint(c.Query("user_b"), 10, 64)
		if errA != nil || errB != nil || userA == 0 || userB == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "user_a and user_b are required"})
			return
		}

		var messages []DMResponse
		if err := db.Raw(`
			SELECT dm.*, COALESCE(u.profile_picture, '') AS sender_profile_picture
			FROM direct_messages dm
			LEFT JOIN users u ON u.id = dm.sender_id
			WHERE dm.deleted_at IS NULL
			  AND ((dm.sender_id = ? AND dm.recipient_id = ?)
			    OR (dm.sender_id = ? AND dm.recipient_id = ?))
			ORDER BY dm.created_at ASC
		`, userA, userB, userB, userA).Scan(&messages).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load messages"})
			return
		}
		if messages == nil {
			messages = []DMResponse{}
		}
		c.JSON(http.StatusOK, messages)
	}
}

func SendDM(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			SenderID    uint   `json:"sender_id"`
			RecipientID uint   `json:"recipient_id"`
			SenderAlias string `json:"sender_alias"`
			Content     string `json:"content"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if body.SenderID == 0 || body.RecipientID == 0 || body.SenderAlias == "" || body.Content == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "sender_id, recipient_id, sender_alias, and content are required"})
			return
		}

		var sender models.User
		var senderRole string
		if db.First(&sender, body.SenderID).Error == nil {
			senderRole = sender.Role
		}

		msg := models.DirectMessage{
			SenderID:    body.SenderID,
			RecipientID: body.RecipientID,
			SenderAlias: body.SenderAlias,
			SenderRole:  senderRole,
			Content:     body.Content,
		}
		if err := db.Create(&msg).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to send message"})
			return
		}
		c.JSON(http.StatusCreated, msg)
	}
}
