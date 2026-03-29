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
			handleSponsorRelapseResponse(db, body.UserID)
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

// GetCheckInStats returns aggregated stats derived from a user's check-in history,
// plus pause/demotion state for sponsor-tier relapse handling.
func GetCheckInStats(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDStr := c.Param("user_id")

		// Load user for OriginalRole and SponsorProgressResetAt
		var user models.User
		if err := db.First(&user, userIDStr).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}

		// Load all check-ins chronologically
		var checkIns []models.CheckIn
		if err := db.Where("user_id = ? AND deleted_at IS NULL", userIDStr).
			Order("created_at asc").
			Find(&checkIns).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load check-ins"})
			return
		}

		// Aggregate
		uniqueDays := map[string]bool{}
		var lastRelapseTime *time.Time
		for i := range checkIns {
			day := checkIns[i].CreatedAt.UTC().Format("2006-01-02")
			uniqueDays[day] = true
			if checkIns[i].Relapsed {
				t := checkIns[i].CreatedAt
				lastRelapseTime = &t
			}
		}

		// Days clean
		daysClean := 0
		if lastRelapseTime != nil {
			daysClean = int(time.Since(*lastRelapseTime).Hours() / 24)
		} else {
			daysClean = int(time.Since(user.CreatedAt).Hours() / 24)
		}

		// Progress check-ins: respects reset date for 3rd-relapse suspension
		progressCheckIns := len(checkIns)
		if user.SponsorProgressResetAt != nil {
			progressCheckIns = 0
			for i := range checkIns {
				if checkIns[i].CreatedAt.After(*user.SponsorProgressResetAt) {
					progressCheckIns++
				}
			}
		}

		// Pause state
		isSponsorTier := user.Role == "sponsor" || user.Role == "leader" || user.Role == "influencer" ||
			user.OriginalRole != ""

		pauseTier := 0
		pauseDaysRemaining := 0
		var pauseEndsAtStr interface{} = nil

		if lastRelapseTime != nil {
			if isSponsorTier {
				sixMonthsAgo := time.Now().AddDate(0, -6, 0)
				var recentCount int64
				db.Model(&models.CheckIn{}).
					Where("user_id = ? AND relapsed = true AND created_at >= ? AND deleted_at IS NULL",
						user.ID, sixMonthsAgo).
					Count(&recentCount)

				switch {
				case recentCount >= 3:
					pauseTier = 3
					// Tier 3 ends when progress threshold is re-earned, not by time
				case recentCount == 2:
					pauseTier = 2
					endsAt := lastRelapseTime.Add(60 * 24 * time.Hour)
					if endsAt.After(time.Now()) {
						pauseDaysRemaining = int(time.Until(endsAt).Hours()/24) + 1
						pauseEndsAtStr = endsAt.UTC().Format(time.RFC3339)
					}
				case recentCount == 1:
					pauseTier = 1
					endsAt := lastRelapseTime.Add(30 * 24 * time.Hour)
					if endsAt.After(time.Now()) {
						pauseDaysRemaining = int(time.Until(endsAt).Hours()/24) + 1
						pauseEndsAtStr = endsAt.UTC().Format(time.RFC3339)
					}
				}
			} else {
				// Regular member: 30-day visual pause only
				endsAt := lastRelapseTime.Add(30 * 24 * time.Hour)
				if endsAt.After(time.Now()) {
					pauseTier = 1
					pauseDaysRemaining = int(time.Until(endsAt).Hours()/24) + 1
					pauseEndsAtStr = endsAt.UTC().Format(time.RFC3339)
				}
			}
		}

		var lastRelapseStr interface{} = nil
		if lastRelapseTime != nil {
			lastRelapseStr = lastRelapseTime.UTC().Format(time.RFC3339)
		}

		c.JSON(http.StatusOK, gin.H{
			"total_check_ins":    len(checkIns),
			"progress_check_ins": progressCheckIns,
			"days_active":        len(uniqueDays),
			"days_clean":         daysClean,
			"last_relapse_at":    lastRelapseStr,
			"pause_tier":         pauseTier,
			"pause_days_remaining": pauseDaysRemaining,
			"pause_ends_at":      pauseEndsAtStr,
			"is_demoted":         user.OriginalRole != "",
			"original_role":      user.OriginalRole,
		})
	}
}

// ── Relapse response helpers ───────────────────────────────────────────────────

// handleSponsorRelapseResponse applies tiered consequences for sponsors/leaders who relapse.
// Regular members only get the standard notification; no further action is taken here.
func handleSponsorRelapseResponse(db *gorm.DB, userID uint) {
	var user models.User
	if err := db.First(&user, userID).Error; err != nil {
		return
	}

	isSponsorTier := user.Role == "sponsor" || user.Role == "leader" || user.Role == "influencer" ||
		user.OriginalRole != ""
	if !isSponsorTier {
		return
	}

	sixMonthsAgo := time.Now().AddDate(0, -6, 0)
	var recentCount int64
	db.Model(&models.CheckIn{}).
		Where("user_id = ? AND relapsed = true AND created_at >= ? AND deleted_at IS NULL",
			userID, sixMonthsAgo).
		Count(&recentCount)

	switch {
	case recentCount >= 3:
		// 3rd relapse: suspend sponsor status, reset progress threshold from scratch
		now := time.Now()
		updates := map[string]interface{}{
			"sponsor_progress_reset_at": now,
		}
		if user.OriginalRole == "" {
			updates["original_role"] = user.Role
			updates["role"] = "apprentice"
		}
		db.Model(&models.User{}).Where("id = ?", userID).Updates(updates)
		reassignSponseesOf(db, user,
			"Your sponsor needs to step fully back from their role to focus on recovery. "+
				"You've been unassigned — please reach out to your group leader for support.")

	case recentCount == 2:
		// 2nd relapse within 6 months: 60-day pause, step down to apprentice
		if user.OriginalRole == "" {
			db.Model(&models.User{}).Where("id = ?", userID).Updates(map[string]interface{}{
				"original_role": user.Role,
				"role":          "apprentice",
			})
		}
		reassignSponseesOf(db, user,
			"Your sponsor is taking 60 days to focus on their own recovery. "+
				"You've been temporarily unassigned — your connection with them can continue when they return.")

	case recentCount == 1:
		// 1st relapse: 30-day pause, reassign sponsees (role unchanged)
		reassignSponseesOf(db, user,
			"Your sponsor has logged a relapse and is taking 30 days for themselves. "+
				"You've been temporarily unassigned — they may return after their pause.")
	}
}

func reassignSponseesOf(db *gorm.DB, sponsor models.User, message string) {
	var sponsees []models.User
	db.Where("sponsor_id = ? AND deleted_at IS NULL", sponsor.ID).Find(&sponsees)
	if len(sponsees) == 0 {
		return
	}

	db.Model(&models.User{}).Where("sponsor_id = ?", sponsor.ID).Update("sponsor_id", 0)

	for _, s := range sponsees {
		db.Create(&models.Notification{
			RecipientID: s.ID,
			SenderID:    sponsor.ID,
			Type:        "sponsor_paused",
			Message:     message,
		})
	}
}

// notifyOnRelapse creates notification records for the group leader and sponsor when a
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
