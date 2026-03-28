package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// GetAvailableSponsors returns sponsors in the group who are marked as available.
func GetAvailableSponsors(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID := c.Param("id")

		type SponsorRow struct {
			ID    uint   `json:"id"`
			Alias string `json:"alias"`
			Role  string `json:"role"`
		}
		var sponsors []SponsorRow
		if err := db.Model(&models.User{}).
			Select("id, alias, role").
			Where("group_id = ? AND role = ? AND is_available = ?", groupID, "sponsor", true).
			Find(&sponsors).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load sponsors"})
			return
		}

		c.JSON(http.StatusOK, sponsors)
	}
}

// RequestSponsor sets the user's sponsor and notifies the sponsor.
func RequestSponsor(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}

		var body struct {
			SponsorID uint `json:"sponsor_id"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if body.SponsorID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "sponsor_id is required"})
			return
		}

		if err := db.Model(&models.User{}).
			Where("id = ?", userID).
			Update("sponsor_id", body.SponsorID).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to assign sponsor"})
			return
		}

		// Notify the sponsor.
		var user models.User
		if db.First(&user, userID).Error == nil {
			notification := models.Notification{
				RecipientID: body.SponsorID,
				SenderID:    uint(userID),
				Type:        "sponsor_request",
				Message:     user.Alias + " has selected you as their sponsor.",
			}
			db.Create(&notification)
		}

		c.JSON(http.StatusOK, gin.H{"sponsor_id": body.SponsorID})
	}
}
