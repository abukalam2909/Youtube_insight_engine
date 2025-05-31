import { ingestChannel, getAnalysisResults, analyzeComments } from './api.js';
import { createSentimentChart, createEngagementChart, formatNumber, decodeHtmlEntities } from './charts.js';

// Global state
let processedVideos = [];
let totalStats = { views: 0, comments: 0, likes: 0 };
let initialChannelName = "";
let alreadyShown = new Set();

// DOM elements
const analyzeBtn = document.getElementById('analyzeBtn');
const backBtn = document.getElementById('backBtn');
const analyzeCommentsBtn = document.getElementById('analyzeCommentsBtn');
const analyzeToggle = document.getElementById('analyzeToggle');
const toggleStatus = document.getElementById('toggleStatus');

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    // Add floating animation to cards
    const cards = document.querySelectorAll('.card');
    cards.forEach((card, index) => {
        card.style.animationDelay = `${index * 0.1}s`;
    });
    
    // Add hover effects to input fields
    const inputs = document.querySelectorAll('input[type="text"]');
    inputs.forEach(input => {
        input.addEventListener('focus', function() {
            this.parentElement.style.transform = 'translateY(-2px)';
        });
        
        input.addEventListener('blur', function() {
            this.parentElement.style.transform = 'translateY(0)';
        });
    });

    // Event listeners
    analyzeToggle.addEventListener('change', toggleAnalysis);
    analyzeBtn.addEventListener('click', startAnalysis);
    backBtn.addEventListener('click', goBack);
    analyzeCommentsBtn.addEventListener('click', analyseComments);
});

/**
 * Toggle analysis mode
 */
function toggleAnalysis() {
    toggleStatus.textContent = this.checked ? 'Advanced Analytics Enabled' : 'Basic Mode Active';
    toggleStatus.className = this.checked ? 'pulse' : '';
}

/**
 * Start channel analysis
 */
async function startAnalysis() {
    const channelInput = document.getElementById('channelInput').value.trim();
    const analyseComments = document.getElementById('analyzeToggle').checked;

    if (!channelInput) {
        showError('Please enter a Channel ID or Channel Name');
        return;
    }

    showLoading(true);
    hideError();

    try {
        const ingestData = await ingestChannel(channelInput, analyseComments);
        console.log("Ingest response:", ingestData);

        const channelId = ingestData.channel_id || channelInput;
        const channelName = ingestData.channel_name || channelInput;
        const maxVideoCount = ingestData.video_count || 25;

        initDisplayResults(channelName);

        if (analyseComments) {
            setTimeout(() => {
                pollResults(channelId, maxVideoCount);
            }, 3000); // Wait 3 seconds before polling
        } else {
            showLoading(false);
            showMessage("Channel metadata stored. Sentiment analysis was skipped.");
        }

    } catch (err) {
        console.error(err);
        showError("Failed to fetch data from backend.");
        showLoading(false);
    }
}

/**
 * Poll for analysis results
 * @param {string} channelId 
 * @param {number} maxVideoCount 
 * @param {number} attempt 
 */
async function pollResults(channelId, maxVideoCount, attempt = 1) {
    try {
        console.log(`Polling attempt ${attempt}...`);
        const data = await getAnalysisResults(channelId);
        const videos = Array.isArray(data) ? data : data.videos || [];
        console.log(`Fetched ${videos.length} videos.`);

        const newVideos = videos.filter(video => !alreadyShown.has(video.video_id));
        newVideos.forEach(video => alreadyShown.add(video.video_id));

        appendToResults(newVideos);

        if (alreadyShown.size < maxVideoCount && attempt < 20) {
            setTimeout(() => pollResults(channelId, maxVideoCount, attempt + 1), 5000);
        } else {
            showLoading(false);
        }
    } catch (err) {
        console.error("Polling error:", err);
        showError("Error retrieving results. Please try again.");
        showLoading(false);
    }
}

/**
 * Initialize the results display
 * @param {string} channelName 
 */
function initDisplayResults(channelName) {
    initialChannelName = channelName;
    processedVideos = [];
    totalStats = { views: 0, comments: 0, likes: 0 };
    alreadyShown = new Set();

    document.getElementById('homePage').classList.add('hidden');
    document.getElementById('resultsPage').classList.remove('hidden');

    document.getElementById('channelInfo').innerHTML = `
        <h2>${channelName}</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <span class="stat-number" id="statVideos">0</span>
                <div class="stat-label">Videos Analyzed</div>
            </div>
            <div class="stat-card">
                <span class="stat-number" id="statViews">0</span>
                <div class="stat-label">Total Views</div>
            </div>
            <div class="stat-card">
                <span class="stat-number" id="statComments">0</span>
                <div class="stat-label">Total Comments</div>
            </div>
            <div class="stat-card">
                <span class="stat-number" id="statLikes">0</span>
                <div class="stat-label">Total Likes</div>
            </div>
        </div>
    `;

    document.getElementById('videoResults').innerHTML = '';
}

/**
 * Append new videos to results
 * @param {Array} newVideos 
 */
function appendToResults(newVideos) {
    const container = document.getElementById('videoResults');

    newVideos.forEach(video => {
        if (processedVideos.some(v => v.video_id === video.video_id)) return;

        processedVideos.push(video);
        totalStats.views += video.engagement_data?.views || 0;
        totalStats.comments += video.engagement_data?.comments || 0;
        totalStats.likes += video.engagement_data?.likes || 0;

        const card = createVideoCard(video);
        container.appendChild(card);
    });

    // Update stats display
    document.getElementById('statVideos').textContent = processedVideos.length;
    document.getElementById('statViews').textContent = formatNumber(totalStats.views);
    document.getElementById('statComments').textContent = formatNumber(totalStats.comments);
    document.getElementById('statLikes').textContent = formatNumber(totalStats.likes);
}

/**
 * Create a video card element
 * @param {Object} video 
 * @returns {HTMLElement}
 */
function createVideoCard(video) {
    const card = document.createElement('div');
    card.className = 'video-card';
    
    const sentimentData = video.sentiment_data || { positive: 0, neutral: 0, negative: 0 };
    const engagementData = video.engagement_data || { likes: 0, comments: 0, views: 0 };
    const decodedTitle = decodeHtmlEntities(video.title);
    
    card.innerHTML = `
        <div class="video-title">${decodedTitle}</div>
        <div class="video-id-container">
            <span class="video-id-label">VIDEO ID:</span>
            <span class="video-id">${video.video_id}</span>
        </div>
        
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 30px;">
            <div>
                <h3 style="color: var(--youtube-white); margin-bottom: 15px; font-size: 1.2rem;">💭 Sentiment Distribution</h3>
                <div class="chart-container">
                    <canvas id="sentiment-${video.video_id}"></canvas>
                </div>
            </div>
            <div>
                <h3 style="color: var(--youtube-white); margin-bottom: 15px; font-size: 1.2rem;"> Engagement Metrics</h3>
                <div class="chart-container">
                    <canvas id="engagement-${video.video_id}"></canvas>
                </div>
            </div>
        </div>
    `;
    
    setTimeout(() => {
        createSentimentChart(`sentiment-${video.video_id}`, sentimentData);
        createEngagementChart(`engagement-${video.video_id}`, engagementData);
    }, 100);
    
    return card;
}

/**
 * Analyze comments for a specific video
 */
async function analyseComments() {
    const videoId = document.getElementById('videoIdInput').value.trim();
    const query = document.getElementById('queryInput').value.trim();
    
    if (!videoId || !query) {
        showCommentError('Please enter both Video ID and Analysis Query');
        return;
    }

    showCommentLoading(true);
    hideCommentMessages();

    try {
        const analysisData = await analyzeComments(videoId, query);
        console.log('Comment analysis response:', analysisData);

        let analysisText = 'No analysis available';
        if (analysisData.llm_generated_analysis && 
            Array.isArray(analysisData.llm_generated_analysis) && 
            analysisData.llm_generated_analysis.length > 0 &&
            analysisData.llm_generated_analysis[0].text) {
            analysisText = analysisData.llm_generated_analysis[0].text;
        }

        showCommentSuccess(analysisText);
        
        // Clear form
        document.getElementById('videoIdInput').value = '';
        document.getElementById('queryInput').value = '';
        
    } catch (error) {
        console.error('Comment analysis error:', error);
        showCommentError(`Failed to analyze comments: ${error.message}`);
    } finally {
        showCommentLoading(false);
    }
}

/**
 * Go back to home page
 */
function goBack() {
    document.getElementById('resultsPage').classList.add('hidden');
    document.getElementById('homePage').classList.remove('hidden');
}

/**
 * Show loading state
 * @param {boolean} show 
 */
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
    document.getElementById('analyzeBtn').disabled = show;
    
    if (show) {
        document.getElementById('analyzeBtn').textContent = '⏳ Processing...';
    } else {
        document.getElementById('analyzeBtn').textContent = '🚀 Launch Analysis';
    }
}

/**
 * Show comment loading state
 * @param {boolean} show 
 */
function showCommentLoading(show) {
    const loadingEl = document.getElementById('commentLoading');
    const analyzeBtn = document.getElementById('analyzeCommentsBtn');
    
    if (show) {
        loadingEl.classList.remove('hidden');
        analyzeBtn.disabled = true;
        analyzeBtn.textContent = '🧠 Analyzing...';
    } else {
        loadingEl.classList.add('hidden');
        analyzeBtn.disabled = false;
        analyzeBtn.textContent = '🧠 Generate AI Insights';
    }
}

/**
 * Show error message
 * @param {string} message 
 */
function showError(message) {
    const errorEl = document.getElementById('errorMessage');
    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
}

/**
 * Hide error message
 */
function hideError() {
    document.getElementById('errorMessage').classList.add('hidden');
}

/**
 * Show comment error message
 * @param {string} message 
 */
function showCommentError(message) {
    const errorEl = document.getElementById('commentError');
    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
}

/**
 * Show comment success message
 * @param {string} message 
 */
function showCommentSuccess(message) {
    const successEl = document.getElementById('commentSuccess');
    successEl.textContent = message;
    successEl.classList.remove('hidden');
}

/**
 * Hide comment messages
 */
function hideCommentMessages() {
    document.getElementById('commentError').classList.add('hidden');
    document.getElementById('commentSuccess').classList.add('hidden');
}

/**
 * Show generic message
 * @param {string} message 
 */
function showMessage(message) {
    const successEl = document.getElementById('errorMessage');
    successEl.textContent = message;
    successEl.classList.remove('error');
    successEl.classList.add('success');
    successEl.classList.remove('hidden');
}