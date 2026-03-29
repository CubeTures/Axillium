package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func TriggerRiskAlert(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		var body struct {
			RiskType string `json:"risk_type"` // "gambling_app" | "bar_location"
			Detail   string `json:"detail"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var user models.User
		if err := db.First(&user, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		// No sponsor — nothing to do, but not an error
		if user.SponsorID == 0 {
			c.JSON(http.StatusOK, gin.H{"status": "no_sponsor"})
			return
		}

		var msg string
		switch body.RiskType {
		case "gambling_app":
			msg = user.Alias + " has opened a gambling app (" + body.Detail + "). Consider reaching out."
		case "bar_location":
			msg = user.Alias + " appears to be near a bar. Consider reaching out."
		default:
			msg = user.Alias + " may be in a risky situation. Consider reaching out."
		}

		db.Create(&models.Notification{
			RecipientID: user.SponsorID,
			SenderID:    uint(userID),
			Type:        "risk_alert",
			Message:     msg,
		})

		c.JSON(http.StatusOK, gin.H{"status": "notified"})
	}
}
