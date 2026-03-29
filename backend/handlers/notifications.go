package handlers

import (
	"net/http"
	"time"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type NotificationRow struct {
	ID          uint      `json:"id"`
	Type        string    `json:"type"`
	Message     string    `json:"message"`
	SenderID    uint      `json:"sender_id"`
	SenderAlias string    `json:"sender_alias"`
	CreatedAt   time.Time `json:"created_at"`
}

func GetNotifications(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("id")
		var rows []NotificationRow
		if err := db.Raw(`
			SELECT n.id, n.type, n.message, n.sender_id, u.alias as sender_alias, n.created_at
			FROM notifications n
			LEFT JOIN users u ON u.id = n.sender_id
			WHERE n.recipient_id = ? AND n.read = false AND n.deleted_at IS NULL
			ORDER BY n.created_at DESC
		`, userID).Scan(&rows).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load notifications"})
			return
		}
		if rows == nil {
			rows = []NotificationRow{}
		}
		c.JSON(http.StatusOK, rows)
	}
}

func MarkNotificationRead(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		notifID := c.Param("notif_id")
		recipientID := c.Param("id")
		db.Model(&models.Notification{}).
			Where("id = ? AND recipient_id = ?", notifID, recipientID).
			Update("read", true)
		c.JSON(http.StatusOK, gin.H{"status": "read"})
	}
}
