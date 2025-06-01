// Configuration
const API_BASE_URL = window._env_?.API_BASE_URL;

/**
 * Ingest channel data
 * @param {string} channelInput 
 * @param {boolean} analyseComments 
 * @returns {Promise<Object>}
 */
export async function ingestChannel(channelInput, analyseComments) {
    const response = await fetch(`${API_BASE_URL}/ingest-channel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            channel_name: channelInput,
            analyse_comments: analyseComments
        })
    });

    if (!response.ok) {
        throw new Error(`Failed to ingest channel: ${response.status}`);
    }

    return await response.json();
}

/**
 * Get analysis results
 * @param {string} channelId 
 * @returns {Promise<Array>}
 */
export async function getAnalysisResults(channelId) {
    const response = await fetch(`${API_BASE_URL}/get-analysis-results`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ channel_id: channelId })
    });

    if (!response.ok) {
        throw new Error(`Failed to get analysis results: ${response.status}`);
    }

    const text = await response.text();
    return JSON.parse(text);
}

/**
 * Analyze comments for a specific video
 * @param {string} videoId 
 * @param {string} query 
 * @returns {Promise<Object>}
 */
export async function analyzeComments(videoId, query) {
    const response = await fetch(`${API_BASE_URL}/analyze-comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            video_id: videoId,
            query: query
        })
    });

    if (!response.ok) {
        throw new Error(`Failed to analyze comments: ${response.status}`);
    }

    const text = await response.text();
    return JSON.parse(text);
}