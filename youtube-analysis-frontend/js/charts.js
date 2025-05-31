/**
 * Create a sentiment chart
 * @param {string} canvasId 
 * @param {Object} data 
 */
export function createSentimentChart(canvasId, data) {
    const ctx = document.getElementById(canvasId).getContext('2d');
    return new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Positive', 'Neutral', 'Negative'],
            datasets: [{
                data: [data.positive, data.neutral, data.negative],
                backgroundColor: [
                    '#00C851',
                    '#FF8800', 
                    '#FF4444'
                ],
                borderWidth: 3,
                borderColor: 'rgba(255, 255, 255, 0.1)',
                hoverBorderWidth: 4,
                hoverBorderColor: '#FFFFFF'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        color: '#FFFFFF',
                        font: {
                            family: 'Inter',
                            size: 12,
                            weight: 500
                        },
                        padding: 20,
                        usePointStyle: true,
                        pointStyle: 'circle'
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 15, 15, 0.9)',
                    titleColor: '#FFFFFF',
                    bodyColor: '#FFFFFF',
                    borderColor: 'rgba(255, 255, 255, 0.2)',
                    borderWidth: 1,
                    cornerRadius: 12,
                    displayColors: true
                }
            },
            cutout: '60%',
            elements: {
                arc: {
                    borderRadius: 8
                }
            }
        }
    });
}

/**
 * Create an engagement chart
 * @param {string} canvasId 
 * @param {Object} data 
 */
export function createEngagementChart(canvasId, data) {
    const ctx = document.getElementById(canvasId).getContext('2d');
    return new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Views', 'Likes', 'Comments'],
            datasets: [{
                data: [data.views, data.likes, data.comments],
                backgroundColor: [
                    'rgba(255, 0, 0, 0.8)',
                    'rgba(6, 95, 212, 0.8)',
                    'rgba(0, 212, 255, 0.8)'
                ],
                borderRadius: 12,
                borderSkipped: false,
                borderWidth: 2,
                borderColor: [
                    'rgba(255, 0, 0, 1)',
                    'rgba(6, 95, 212, 1)',
                    'rgba(0, 212, 255, 1)'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(15, 15, 15, 0.9)',
                    titleColor: '#FFFFFF',
                    bodyColor: '#FFFFFF',
                    borderColor: 'rgba(255, 255, 255, 0.2)',
                    borderWidth: 1,
                    cornerRadius: 12,
                    callbacks: {
                        label: function(context) {
                            return context.label + ': ' + formatNumber(context.parsed.y);
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: {
                        display: false
                    },
                    ticks: {
                        color: '#FFFFFF',
                        font: {
                            family: 'Inter',
                            size: 11,
                            weight: 500
                        }
                    }
                },
                y: {
                    beginAtZero: true,
                    grid: {
                        color: 'rgba(255, 255, 255, 0.1)',
                        borderDash: [5, 5]
                    },
                    ticks: {
                        color: '#FFFFFF',
                        font: {
                            family: 'Inter',
                            size: 11
                        },
                        callback: function(value) {
                            return formatNumber(value);
                        }
                    }
                }
            },
            elements: {
                bar: {
                    borderRadius: 8
                }
            }
        }
    });
}

/**
 * Format large numbers with K/M suffixes
 * @param {number} num 
 * @returns {string}
 */
export function formatNumber(num) {
    if (num >= 1000000) {
        return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
        return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
}

/**
 * Decode HTML entities in text
 * @param {string} text 
 * @returns {string}
 */
export function decodeHtmlEntities(text) {
    const textArea = document.createElement('textarea');
    textArea.innerHTML = text;
    return textArea.value;
}