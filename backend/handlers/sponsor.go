package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type SponsorRequestRow struct {
	NotifID  uint   `json:"notif_id"`
	SenderID uint   `json:"sender_id"`
	Alias    string `json:"alias"`
	Message  string `json:"message"`
}

func GetSponsorRequests(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		var requests []SponsorRequestRow
		if err := db.Raw(`
			SELECT n.id as notif_id, n.sender_id, u.alias, n.message
			FROM notifications n
			JOIN users u ON u.id = n.sender_id
			WHERE n.recipient_id = ? AND n.type = 'sponsor_request' AND n.read = false AND n.deleted_at IS NULL
			  AND (u.sponsor_id IS NULL OR u.sponsor_id = 0 OR u.sponsor_id != n.recipient_id)
		`, userID).Scan(&requests).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load sponsor requests"})
			return
		}
		if requests == nil {
			requests = []SponsorRequestRow{}
		}
		c.JSON(http.StatusOK, requests)
	}
}

func AcceptSponsorRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sponsorID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		notifID, err := strconv.ParseUint(c.Param("notif_id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid notification id"})
			return
		}

		var notif models.Notification
		if err := db.Where("id = ? AND recipient_id = ? AND type = 'sponsor_request'", notifID, sponsorID).
			First(&notif).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "request not found"})
			return
		}

		// Set sponsor on the apprentice.
		if err := db.Model(&models.User{}).Where("id = ?", notif.SenderID).
			Update("sponsor_id", sponsorID).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to assign sponsor"})
			return
		}

		db.Model(&notif).Update("read", true)

		// Notify the apprentice that their request was accepted.
		var sponsor models.User
		if db.First(&sponsor, sponsorID).Error == nil {
			db.Create(&models.Notification{
				RecipientID: notif.SenderID,
				SenderID:    uint(sponsorID),
				Type:        "sponsor_accepted",
				Message:     sponsor.Alias + " has accepted your sponsor request.",
			})
		}

		c.JSON(http.StatusOK, gin.H{"status": "accepted"})
	}
}

func DeclineSponsorRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sponsorID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		notifID, err := strconv.ParseUint(c.Param("notif_id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid notification id"})
			return
		}

		var notif models.Notification
		if err := db.Where("id = ? AND recipient_id = ? AND type = 'sponsor_request'", notifID, sponsorID).
			First(&notif).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "request not found"})
			return
		}

		db.Model(&notif).Update("read", true)
		c.JSON(http.StatusOK, gin.H{"status": "declined"})
	}
}

func GetApprentices(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sponsorID := c.Param("id")
		type ApprenticeRow struct {
			ID    uint   `json:"id"`
			Alias string `json:"alias"`
			Role  string `json:"role"`
		}
		var apprentices []ApprenticeRow
		if err := db.Model(&models.User{}).Select("id, alias, role").
			Where("sponsor_id = ?", sponsorID).Find(&apprentices).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load apprentices"})
			return
		}
		if apprentices == nil {
			apprentices = []ApprenticeRow{}
		}
		c.JSON(http.StatusOK, apprentices)
	}
}

func GetUserBasic(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("id")
		type UserRow struct {
			ID    uint   `json:"id"`
			Alias string `json:"alias"`
			Role  string `json:"role"`
		}
		var user UserRow
		if err := db.Model(&models.User{}).Select("id, alias, role").
			Where("id = ?", userID).First(&user).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		c.JSON(http.StatusOK, user)
	}
}

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

		// Do not set sponsor_id yet — wait for the sponsor to accept.
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

		c.JSON(http.StatusOK, gin.H{"status": "request_sent"})
	}
}

type OutgoingRequestRow struct {
	NotifID     uint   `json:"notif_id"`
	SponsorID   uint   `json:"sponsor_id"`
	SponsorAlias string `json:"sponsor_alias"`
}

func RemoveSponsor(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		if err := db.Model(&models.User{}).Where("id = ?", userID).
			Update("sponsor_id", 0).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to remove sponsor"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "removed"})
	}
}

func RemoveApprentice(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sponsorID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid sponsor id"})
			return
		}
		apprenticeID, err := strconv.ParseUint(c.Param("apprentice_id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid apprentice id"})
			return
		}
		// Only clear if this sponsor is actually their sponsor.
		if err := db.Model(&models.User{}).
			Where("id = ? AND sponsor_id = ?", apprenticeID, sponsorID).
			Update("sponsor_id", 0).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to remove apprentice"})
			return
		}
		// Mark the original sponsor request notification as read so the sponsee
		// no longer sees a pending request on their end.
		db.Model(&models.Notification{}).
			Where("sender_id = ? AND recipient_id = ? AND type = 'sponsor_request'", apprenticeID, sponsorID).
			Update("read", true)
		c.JSON(http.StatusOK, gin.H{"status": "removed"})
	}
}

func GetOutgoingSponsorRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		var row OutgoingRequestRow
		err = db.Raw(`
			SELECT n.id as notif_id, n.recipient_id as sponsor_id, u.alias as sponsor_alias
			FROM notifications n
			JOIN users u ON u.id = n.recipient_id
			WHERE n.sender_id = ? AND n.type = 'sponsor_request' AND n.read = false AND n.deleted_at IS NULL
			LIMIT 1
		`, userID).Scan(&row).Error
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load request"})
			return
		}
		if row.NotifID == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "no pending request"})
			return
		}
		c.JSON(http.StatusOK, row)
	}
}

func CancelSponsorRequest(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		var notif models.Notification
		if err := db.Where("sender_id = ? AND type = 'sponsor_request' AND read = false", userID).
			First(&notif).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "no pending request"})
			return
		}
		db.Model(&notif).Update("read", true)
		// Clear sponsor_id if it was set via the old immediate-assign flow.
		db.Model(&models.User{}).Where("id = ? AND sponsor_id = ?", userID, notif.RecipientID).
			Update("sponsor_id", 0)
		c.JSON(http.StatusOK, gin.H{"status": "cancelled"})
	}
}
