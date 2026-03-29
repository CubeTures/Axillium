package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

var promptSetterRoles = map[string]bool{
	"sponsor":    true,
	"leader":     true,
	"influencer": true,
}

var promptResponderRoles = map[string]bool{
	"apprentice": true,
	"sponsor":    true,
	"leader":     true,
	"influencer": true,
	"graduated":  true,
}

var suggestedPrompts = []string{
	"What small win this week reminded you why you started?",
	"Describe a moment when you chose recovery over old habits. What made the difference?",
	"What does a 'good day' in recovery look like for you right now?",
	"Who or what has been your anchor this week, and how can you thank them?",
	"What is one thing you know today that you wish you knew when you first started?",
	"What coping strategy surprised you by actually working?",
	"How has your relationship with yourself changed since you began this journey?",
	"What does freedom from addiction mean to you in practical, day-to-day terms?",
	"Share a moment where you felt genuine pride in your progress, however small.",
	"What is a fear you have faced recently — inside or outside of recovery?",
	"Describe a boundary you set this week. How did it feel to hold it?",
	"What part of your old life do you grieve, and how are you making peace with that?",
	"Who in your life has noticed a change in you recently? What did they say?",
	"What would you say to a version of yourself from six months ago?",
	"What does your morning routine look like now compared to before, and why does it matter?",
	"How do you distinguish a craving from a need? What helps you in that moment?",
	"What community or connection has surprised you most on this journey?",
	"Describe a time you asked for help. What did that take?",
	"What does the word 'recovery' mean to you this week — has it shifted from before?",
	"If you had to name one thing keeping you going right now, what would it be?",
}

// GetCurrentPrompt returns the active prompt for the current ISO week.
// Returns 200 with {"iso_week": "...", "prompt": null} if none is set yet.
func GetCurrentPrompt(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		week := currentISOWeek()
		var prompt models.WeeklyPrompt
		err := db.Where("iso_week = ?", week).First(&prompt).Error
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"iso_week": week, "prompt": nil})
			return
		}
		c.JSON(http.StatusOK, gin.H{"iso_week": week, "prompt": prompt})
	}
}

// SetCurrentPrompt lets sponsors, leaders, and influencers set (or replace)
// the prompt for the current ISO week.
func SetCurrentPrompt(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			UserID     uint   `json:"user_id"`
			UserAlias  string `json:"user_alias"`
			UserRole   string `json:"user_role"`
			PromptText string `json:"prompt_text"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if !promptSetterRoles[body.UserRole] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only sponsors, leaders, and influencers can set the weekly prompt"})
			return
		}
		if body.PromptText == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "prompt_text is required"})
			return
		}

		// Verify the user's role from the DB so the body role cannot be spoofed for access.
		var sender models.User
		if err := db.First(&sender, body.UserID).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "user not found"})
			return
		}
		if !promptSetterRoles[sender.Role] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only sponsors, leaders, and influencers can set the weekly prompt"})
			return
		}

		week := currentISOWeek()

		// Delete the existing prompt for this week if one exists, then insert fresh.
		db.Where("iso_week = ?", week).Delete(&models.WeeklyPrompt{})

		prompt := models.WeeklyPrompt{
			ISOWeek:    week,
			PromptText: body.PromptText,
			SetByID:    body.UserID,
			SetByAlias: body.UserAlias,
			SetByRole:  sender.Role,
		}
		if err := db.Create(&prompt).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save prompt"})
			return
		}
		c.JSON(http.StatusCreated, prompt)
	}
}

// GetSuggestedPrompts returns the list of pre-generated prompt options.
// Only sponsors, leaders, and influencers can retrieve suggestions.
func GetSuggestedPrompts(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.Query("role")
		if !promptSetterRoles[role] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only sponsors, leaders, and influencers can view suggestions"})
			return
		}
		c.JSON(http.StatusOK, suggestedPrompts)
	}
}

// GetPromptResponses returns paginated responses for the current week's prompt.
// Returns an empty array if no prompt is set this week.
func GetPromptResponses(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		page := 1
		if p := c.Query("page"); p != "" {
			if n, err := strconv.Atoi(p); err == nil && n > 0 {
				page = n
			}
		}
		offset := (page - 1) * 20

		week := currentISOWeek()
		var prompt models.WeeklyPrompt
		if err := db.Where("iso_week = ?", week).First(&prompt).Error; err != nil {
			c.JSON(http.StatusOK, []models.PromptResponse{})
			return
		}

		responses := make([]models.PromptResponse, 0)
		if err := db.Where("prompt_id = ?", prompt.ID).
			Order("created_at asc").
			Limit(20).
			Offset(offset).
			Find(&responses).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load responses"})
			return
		}
		c.JSON(http.StatusOK, responses)
	}
}

// PostPromptResponse lets any registered user post a reply to the current week's prompt.
func PostPromptResponse(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			UserID    uint   `json:"user_id"`
			UserAlias string `json:"user_alias"`
			UserRole  string `json:"user_role"`
			Content   string `json:"content"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if body.Content == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "content is required"})
			return
		}

		// Verify the user exists and is not anonymous.
		var sender models.User
		if err := db.First(&sender, body.UserID).Error; err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "user not found"})
			return
		}
		if !promptResponderRoles[sender.Role] {
			c.JSON(http.StatusForbidden, gin.H{"error": "register to join the discussion"})
			return
		}

		week := currentISOWeek()
		var prompt models.WeeklyPrompt
		if err := db.Where("iso_week = ?", week).First(&prompt).Error; err != nil {
			c.JSON(http.StatusConflict, gin.H{"error": "no active prompt this week"})
			return
		}

		response := models.PromptResponse{
			PromptID:  prompt.ID,
			UserID:    body.UserID,
			UserAlias: body.UserAlias,
			UserRole:  sender.Role,
			Content:   body.Content,
		}
		if err := db.Create(&response).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to post response"})
			return
		}
		c.JSON(http.StatusCreated, response)
	}
}
