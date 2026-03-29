package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func CreateCheckIn(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			UserID     uint   `json:"user_id"`
			MoodScore  int    `json:"mood_score"`
			Relapsed   bool   `json:"relapsed"`
			Reflection string `json:"reflection"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if body.UserID == 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "user_id is required"})
			return
		}
		if body.MoodScore < 1 || body.MoodScore > 5 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "mood_score must be between 1 and 5"})
			return
		}

		checkIn := models.CheckIn{
			UserID:     body.UserID,
			MoodScore:  body.MoodScore,
			Relapsed:   body.Relapsed,
			Reflection: body.Reflection,
		}
		if err := db.Create(&checkIn).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save check-in"})
			return
		}

		if body.Relapsed {
			notifyOnRelapse(db, body.UserID, checkIn.ID)
		}

		c.JSON(http.StatusCreated, checkIn)
	}
}

// GetTodayCheckIn returns the user's check-in for today if one exists (404 if not).
func GetTodayCheckIn(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")
		now := time.Now().UTC()
		startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
		endOfDay := startOfDay.Add(24 * time.Hour)

		var checkIns []models.CheckIn
		err := db.Where("user_id = ? AND created_at >= ? AND created_at < ?", userID, startOfDay, endOfDay).
			Order("created_at asc").
			Limit(1).
			Find(&checkIns).Error
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to query check-in"})
			return
		}
		if len(checkIns) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"checked_in": false})
			return
		}
		c.JSON(http.StatusOK, checkIns[0])
	}
}

func GetCheckIns(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")
		var checkIns []models.CheckIn
		if err := db.Where("user_id = ?", userID).
			Order("created_at desc").
			Find(&checkIns).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load check-ins"})
			return
		}
		c.JSON(http.StatusOK, checkIns)
	}
}

// notifyOnRelapse creates notification records for the group leader when a
// user reports a relapse. Runs best-effort — failures are logged, not fatal.
func notifyOnRelapse(db *gorm.DB, userID, checkInID uint) {
	var user models.User
	if err := db.First(&user, userID).Error; err != nil {
		return
	}
	if user.GroupID == 0 {
		return
	}

	var group models.Group
	if err := db.First(&group, user.GroupID).Error; err != nil {
		return
	}

	msg := fmt.Sprintf("%s has reported a relapse in their daily check-in.", user.Alias)

	recipients := map[uint]bool{}
	if group.LeaderID > 0 && group.LeaderID != userID {
		recipients[group.LeaderID] = true
	}
	if user.SponsorID > 0 && user.SponsorID != userID {
		recipients[user.SponsorID] = true
	}

	for recipientID := range recipients {
		notification := models.Notification{
			RecipientID: recipientID,
			SenderID:    userID,
			Type:        "relapse_alert",
			Message:     msg,
			Read:        false,
		}
		db.Create(&notification)
	}
}
