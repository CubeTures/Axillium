package handlers

import (
	"net/http"
	"strconv"
	"time"

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

// BecomeSponsor lets an eligible apprentice request to become a sponsor.
// The request is forwarded as a notification to the group leader for sign-off.
func BecomeSponsor(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}

		var user models.User
		if err := db.First(&user, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		if user.Role != "apprentice" {
			c.JSON(http.StatusForbidden, gin.H{"error": "only apprentices can request sponsor status"})
			return
		}
		if user.OriginalRole != "" {
			c.JSON(http.StatusForbidden, gin.H{"error": "restore your previous role before requesting sponsor status"})
			return
		}
		if user.GroupID == 0 {
			c.JSON(http.StatusForbidden, gin.H{"error": "you must be in a group to request sponsor status"})
			return
		}
		var group models.Group
		if err := db.First(&group, user.GroupID).Error; err != nil || group.LeaderID == 0 {
			c.JSON(http.StatusForbidden, gin.H{"error": "your group does not have a leader yet"})
			return
		}

		// Eligibility: 90+ progress check-ins
		var checkIns []models.CheckIn
		db.Where("user_id = ? AND deleted_at IS NULL", userID).Find(&checkIns)
		progressCheckIns := len(checkIns)
		if user.SponsorProgressResetAt != nil {
			progressCheckIns = 0
			for i := range checkIns {
				if checkIns[i].CreatedAt.After(*user.SponsorProgressResetAt) {
					progressCheckIns++
				}
			}
		}
		if progressCheckIns < 90 {
			c.JSON(http.StatusForbidden, gin.H{
				"error":              "90 check-ins required to request sponsor status",
				"progress_check_ins": progressCheckIns,
			})
			return
		}

		// No duplicate pending request
		var existing int64
		db.Model(&models.Notification{}).
			Where("sender_id = ? AND type = 'become_sponsor_request' AND read = false AND deleted_at IS NULL", userID).
			Count(&existing)
		if existing > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "request already pending"})
			return
		}

		notif := models.Notification{
			RecipientID: group.LeaderID,
			SenderID:    uint(userID),
			Type:        "become_sponsor_request",
			Message:     user.Alias + " has met the eligibility threshold and would like to become a sponsor.",
		}
		if err := db.Create(&notif).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to send request"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "pending"})
	}
}

// GetBecomeSponsorStatus returns the pending become-sponsor request for a user, if one exists.
func GetBecomeSponsorStatus(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}
		var notif models.Notification
		if err := db.Where("sender_id = ? AND type = 'become_sponsor_request' AND read = false AND deleted_at IS NULL", userID).
			First(&notif).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "no pending request"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"notif_id": notif.ID})
	}
}

// ApproveBecomeSponsors allows a leader to approve a become-sponsor request.
func ApproveBecomeSponsors(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		leaderID, err := strconv.ParseUint(c.Param("id"), 10, 64)
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
		if err := db.Where("id = ? AND recipient_id = ? AND type = 'become_sponsor_request'", notifID, leaderID).
			First(&notif).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "request not found"})
			return
		}

		if err := db.Model(&models.User{}).Where("id = ?", notif.SenderID).
			Update("role", "sponsor").Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update role"})
			return
		}

		db.Model(&notif).Update("read", true)

		leaderAlias := "Your leader"
		var leader models.User
		if db.First(&leader, leaderID).Error == nil {
			leaderAlias = leader.Alias
		}
		db.Create(&models.Notification{
			RecipientID: notif.SenderID,
			SenderID:    uint(leaderID),
			Type:        "become_sponsor_approved",
			Message:     leaderAlias + " has approved your request. You are now a sponsor.",
		})

		c.JSON(http.StatusOK, gin.H{"status": "approved"})
	}
}

// DenyBecomeSponsors allows a leader to deny a become-sponsor request.
func DenyBecomeSponsors(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		leaderID, err := strconv.ParseUint(c.Param("id"), 10, 64)
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
		if err := db.Where("id = ? AND recipient_id = ? AND type = 'become_sponsor_request'", notifID, leaderID).
			First(&notif).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "request not found"})
			return
		}

		db.Model(&notif).Update("read", true)

		leaderAlias := "Your leader"
		var leader models.User
		if db.First(&leader, leaderID).Error == nil {
			leaderAlias = leader.Alias
		}
		db.Create(&models.Notification{
			RecipientID: notif.SenderID,
			SenderID:    uint(leaderID),
			Type:        "become_sponsor_denied",
			Message:     leaderAlias + " reviewed your request and isn't ready to approve it yet. Keep showing up.",
		})

		c.JSON(http.StatusOK, gin.H{"status": "denied"})
	}
}

// RestoreSponsorRole allows a demoted sponsor/leader to reclaim their original role
// once their pause period has ended (or once the progress threshold is re-earned for tier 3).
func RestoreSponsorRole(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("id")

		var user models.User
		if err := db.First(&user, userID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		if user.OriginalRole == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "not currently demoted"})
			return
		}

		sixMonthsAgo := time.Now().AddDate(0, -6, 0)
		var recentCount int64
		db.Model(&models.CheckIn{}).
			Where("user_id = ? AND relapsed = true AND created_at >= ? AND deleted_at IS NULL",
				user.ID, sixMonthsAgo).
			Count(&recentCount)

		if recentCount >= 3 {
			// Tier 3: unlock requires re-earning the progress threshold
			var progressCount int64
			if user.SponsorProgressResetAt != nil {
				db.Model(&models.CheckIn{}).
					Where("user_id = ? AND created_at >= ? AND deleted_at IS NULL",
						user.ID, user.SponsorProgressResetAt).
					Count(&progressCount)
			}
			if progressCount < 90 {
				c.JSON(http.StatusForbidden, gin.H{
					"error":           "re-earn 90 check-ins since your last reset to reclaim sponsor status",
					"progress_check_ins": progressCount,
				})
				return
			}
			db.Model(&models.User{}).Where("id = ?", user.ID).Updates(map[string]interface{}{
				"role":          user.OriginalRole,
				"original_role": "",
			})
			c.JSON(http.StatusOK, gin.H{"role": user.OriginalRole})
			return
		}

		// Tier 1 or 2: time-based pause
		pauseDays := 30
		if recentCount == 2 {
			pauseDays = 60
		}

		var lastRelapse models.CheckIn
		if err := db.Where("user_id = ? AND relapsed = true AND deleted_at IS NULL", user.ID).
			Order("created_at desc").First(&lastRelapse).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "could not determine relapse history"})
			return
		}

		pauseEndsAt := lastRelapse.CreatedAt.Add(time.Duration(pauseDays) * 24 * time.Hour)
		if time.Now().Before(pauseEndsAt) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":          "pause period has not ended yet",
				"days_remaining": int(time.Until(pauseEndsAt).Hours()/24) + 1,
			})
			return
		}

		db.Model(&models.User{}).Where("id = ?", user.ID).Updates(map[string]interface{}{
			"role":          user.OriginalRole,
			"original_role": "",
		})
		c.JSON(http.StatusOK, gin.H{"role": user.OriginalRole})
	}
}
