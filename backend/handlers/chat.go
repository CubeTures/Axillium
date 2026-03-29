package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type MessageResponse struct {
	models.Message
	SenderProfilePicture string `json:"sender_profile_picture"`
}

func GetMessages(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")
		page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
		if page < 1 {
			page = 1
		}
		limit := 20
		offset := (page - 1) * limit

		var messages []MessageResponse
		if err := db.Raw(`
			SELECT m.*, COALESCE(u.profile_picture, '') AS sender_profile_picture
			FROM messages m
			LEFT JOIN users u ON u.id = m.user_id
			WHERE m.group_id = ? AND m.deleted_at IS NULL
			ORDER BY m.created_at ASC
			LIMIT ? OFFSET ?
		`, groupID, limit, offset).Scan(&messages).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load messages"})
			return
		}
		if messages == nil {
			messages = []MessageResponse{}
		}

		c.JSON(http.StatusOK, messages)
	}
}

func SendMessage(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}

		var body struct {
			UserID  uint   `json:"user_id"`
			Alias   string `json:"alias"`
			Content string `json:"content"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if body.Content == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "content is required"})
			return
		}
		if body.Alias == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "alias is required"})
			return
		}

		// Look up sender's current role so messages can be distinguished by role.
		var senderRole string
		if body.UserID > 0 {
			var sender models.User
			if db.First(&sender, body.UserID).Error == nil {
				senderRole = sender.Role
			}
		}

		message := models.Message{
			GroupID:    uint(groupID),
			UserID:     body.UserID,
			Alias:      body.Alias,
			SenderRole: senderRole,
			Content:    body.Content,
		}
		if err := db.Create(&message).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save message"})
			return
		}

		c.JSON(http.StatusCreated, message)
	}
}

func GetGroupMembers(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")

		type MemberRow struct {
			ID    uint   `json:"id"`
			Alias string `json:"alias"`
			Role  string `json:"role"`
		}
		var members []MemberRow
		if err := db.Model(&models.User{}).
			Select("id, alias, role").
			Where("group_id = ?", groupID).
			Find(&members).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load members"})
			return
		}

		c.JSON(http.StatusOK, members)
	}
}
