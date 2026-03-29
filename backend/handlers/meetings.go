package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

var meetingOrganizerRoles = map[string]bool{
	"sponsor":    true,
	"leader":     true,
	"influencer": true,
}

// GetMeetings returns all meetings for a group, ordered soonest first.
// Time filtering is intentionally left to the client to avoid SQLite
// timezone string-comparison issues.
func GetMeetings(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.Atoi(c.Param("id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}

		meetings := make([]models.Meeting, 0)
		if err := db.Where("group_id = ?", groupID).
			Order("scheduled_at asc").
			Find(&meetings).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load meetings"})
			return
		}
		c.JSON(http.StatusOK, meetings)
	}
}

// CreateMeeting lets sponsors, leaders, and influencers schedule a physical meeting.
func CreateMeeting(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.Atoi(c.Param("id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}

		var body struct {
			CreatedByID    uint   `json:"created_by_id"`
			CreatedByAlias string `json:"created_by_alias"`
			CreatedByRole  string `json:"created_by_role"`
			Title          string `json:"title"`
			Location       string `json:"location"`
			Note           string `json:"note"`
			ScheduledAt    string `json:"scheduled_at"` // RFC3339
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if body.Title == "" || body.Location == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "title and location are required"})
			return
		}
		if body.ScheduledAt == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "scheduled_at is required"})
			return
		}

		// Verify the user's role from DB.
		var organizer models.User
		if err := db.First(&organizer, body.CreatedByID).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "user not found"})
			return
		}
		if !meetingOrganizerRoles[organizer.Role] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only sponsors, leaders, and influencers can schedule meetings"})
			return
		}

		scheduledAt, err := time.Parse(time.RFC3339, body.ScheduledAt)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "scheduled_at must be RFC3339 format"})
			return
		}
		if scheduledAt.Before(time.Now()) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "scheduled_at must be in the future"})
			return
		}

		meeting := models.Meeting{
			GroupID:        uint(groupID),
			Title:          body.Title,
			Location:       body.Location,
			Note:           body.Note,
			ScheduledAt:    scheduledAt,
			CreatedByID:    body.CreatedByID,
			CreatedByAlias: body.CreatedByAlias,
			CreatedByRole:  organizer.Role,
		}
		if err := db.Create(&meeting).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create meeting"})
			return
		}
		c.JSON(http.StatusCreated, meeting)
	}
}

// DeleteMeeting lets sponsors, leaders, and influencers cancel a meeting.
func DeleteMeeting(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.Atoi(c.Param("id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}
		meetingID, err := strconv.Atoi(c.Param("meeting_id"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid meeting id"})
			return
		}

		// role passed as query param so no body is needed for DELETE
		role := c.Query("role")
		userID := c.Query("user_id")

		var organizer models.User
		if err := db.First(&organizer, userID).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "user not found"})
			return
		}
		if !meetingOrganizerRoles[organizer.Role] || !meetingOrganizerRoles[role] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only sponsors, leaders, and influencers can cancel meetings"})
			return
		}

		var meeting models.Meeting
		if err := db.Where("id = ? AND group_id = ?", meetingID, groupID).First(&meeting).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "meeting not found"})
			return
		}

		if err := db.Delete(&meeting).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to cancel meeting"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "meeting cancelled"})
	}
}
