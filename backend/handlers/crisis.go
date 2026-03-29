package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// POST /api/crisis — create a stage-1 alert and notify personal sponsor
func TriggerCrisis(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			UserID    uint   `json:"user_id"`
			UserAlias string `json:"user_alias"`
			GroupID   uint   `json:"group_id"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.UserID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "user_id, user_alias, and group_id are required"})
			return
		}

		// Only one active alert per user
		var existing models.CrisisAlert
		if err := db.Where("user_id = ? AND resolved = false AND deleted_at IS NULL", body.UserID).First(&existing).Error; err == nil {
			c.JSON(http.StatusConflict, existing)
			return
		}

		alert := models.CrisisAlert{
			UserID:    body.UserID,
			UserAlias: body.UserAlias,
			GroupID:   body.GroupID,
			Stage:     1,
			Resolved:  false,
		}
		if err := db.Create(&alert).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create crisis alert"})
			return
		}

		// Notify personal sponsor if one exists
		var user models.User
		if err := db.First(&user, body.UserID).Error; err == nil && user.SponsorID != 0 {
			db.Create(&models.Notification{
				RecipientID: user.SponsorID,
				SenderID:    body.UserID,
				Type:        "crisis_alert",
				Message:     body.UserAlias + " needs support right now. Please respond if you can.",
			})
		}

		c.JSON(http.StatusCreated, alert)
	}
}

// POST /api/crisis/:id/escalate — advance to the next stage and send notifications
func EscalateCrisis(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		alertID, err := strconv.Atoi(c.Param("id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid alert id"})
			return
		}

		var body struct {
			UserID uint `json:"user_id"`
		}
		c.ShouldBindJSON(&body) //nolint

		var alert models.CrisisAlert
		if err := db.First(&alert, alertID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "alert not found"})
			return
		}
		if alert.Resolved {
			c.JSON(http.StatusOK, alert)
			return
		}
		if body.UserID != 0 && alert.UserID != body.UserID {
			c.JSON(http.StatusForbidden, gin.H{"error": "not your alert"})
			return
		}

		newStage := alert.Stage + 1
		if newStage > 3 {
			c.JSON(http.StatusOK, alert)
			return
		}
		db.Model(&alert).Update("stage", newStage)

		switch newStage {
		case 2:
			// Notify all sponsors/leaders/influencers in the group
			var sponsors []models.User
			db.Where("group_id = ? AND role IN ('sponsor','leader','influencer') AND id != ?", alert.GroupID, alert.UserID).Find(&sponsors)
			for _, s := range sponsors {
				db.Create(&models.Notification{
					RecipientID: s.ID,
					SenderID:    alert.UserID,
					Type:        "crisis_alert",
					Message:     alert.UserAlias + " needs support. Their sponsor hasn't responded — please reach out if you can.",
				})
			}
		case 3:
			// Notify all group members
			var members []models.User
			db.Where("group_id = ? AND id != ?", alert.GroupID, alert.UserID).Find(&members)
			for _, m := range members {
				db.Create(&models.Notification{
					RecipientID: m.ID,
					SenderID:    alert.UserID,
					Type:        "crisis_alert",
					Message:     alert.UserAlias + " needs community support. Please check in if you're available.",
				})
			}
		}

		c.JSON(http.StatusOK, alert)
	}
}

// POST /api/crisis/respond — a sponsor/member responds; resolves the active alert
func RespondToCrisis(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			CrisisUserID   uint   `json:"crisis_user_id"`
			ResponderID    uint   `json:"responder_id"`
			ResponderAlias string `json:"responder_alias"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.CrisisUserID == 0 || body.ResponderID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "crisis_user_id and responder_id are required"})
			return
		}

		var alert models.CrisisAlert
		if err := db.Where("user_id = ? AND resolved = false AND deleted_at IS NULL", body.CrisisUserID).First(&alert).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "no active crisis for that user"})
			return
		}

		db.Model(&alert).Updates(map[string]interface{}{
			"resolved":          true,
			"resolved_by_id":    body.ResponderID,
			"resolved_by_alias": body.ResponderAlias,
		})

		// Notify the person who triggered the alert
		if body.ResponderID != alert.UserID {
			db.Create(&models.Notification{
				RecipientID: alert.UserID,
				SenderID:    body.ResponderID,
				Type:        "crisis_responded",
				Message:     body.ResponderAlias + " is on their way to support you.",
			})
		}

		c.JSON(http.StatusOK, gin.H{"status": "resolved"})
	}
}

// POST /api/crisis/:id/cancel — the user who triggered cancels their own alert
func CancelCrisis(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		alertID, err := strconv.Atoi(c.Param("id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid alert id"})
			return
		}

		var body struct {
			UserID uint `json:"user_id"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.UserID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "user_id required"})
			return
		}

		var alert models.CrisisAlert
		if err := db.First(&alert, alertID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "alert not found"})
			return
		}
		if alert.UserID != body.UserID {
			c.JSON(http.StatusForbidden, gin.H{"error": "not your alert"})
			return
		}

		db.Model(&alert).Updates(map[string]interface{}{
			"resolved":          true,
			"resolved_by_id":    body.UserID,
			"resolved_by_alias": "self",
		})

		c.JSON(http.StatusOK, gin.H{"status": "cancelled"})
	}
}

// GET /api/crisis/active?user_id=X
func GetActiveCrisis(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDStr := c.Query("user_id")
		userID, err := strconv.Atoi(userIDStr)
		if err != nil || userID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "user_id required"})
			return
		}

		var alert models.CrisisAlert
		if err := db.Where("user_id = ? AND resolved = false AND deleted_at IS NULL", userID).First(&alert).Error; err != nil {
			c.JSON(http.StatusOK, gin.H{"alert": nil})
			return
		}
		c.JSON(http.StatusOK, gin.H{"alert": alert})
	}
}
