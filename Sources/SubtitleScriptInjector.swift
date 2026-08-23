import Foundation

struct SubtitleScriptInjector {
    static let scriptSource = """
    (function() {
        if (window.__netflixSubtitleExtractorInstalled) return;
        window.__netflixSubtitleExtractorInstalled = true;

        var lastSubtitleText = '';
        var lastSubtitleTime = 0;
        var subtitleObserver = null;
        var videoElement = null;

        function getActiveVideo() {
            if (videoElement && document.body.contains(videoElement)) return videoElement;
            videoElement = document.querySelector('video');
            return videoElement;
        }

        function getNetflixPlayerAPI() {
            try {
                if (window.netflix && window.netflix.appContext) {
                    var playerApp = window.netflix.appContext.getPlayerApp();
                    if (playerApp) {
                        var api = playerApp.getAPI();
                        if (api && api.videoPlayer) {
                            return api.videoPlayer;
                        }
                    }
                }
            } catch(e) {
                // Ignore API access failure
            }
            return null;
        }

        function getSessionId(player) {
            if (player) {
                try {
                    var sessions = player.getAllPlayerSessionIds();
                    if (sessions && sessions.length > 0) return sessions[0];
                } catch(e) {}
            }
            return null;
        }

        function getCurrentTimeSeconds() {
            var video = getActiveVideo();
            if (video && !isNaN(video.currentTime) && video.currentTime > 0) {
                return video.currentTime;
            }
            var player = getNetflixPlayerAPI();
            var sid = getSessionId(player);
            if (player && sid) {
                try {
                    var ms = player.getCurrentTime(sid);
                    if (ms && !isNaN(ms)) return ms / 1000.0;
                } catch(e) {}
            }
            return 0;
        }

        function formatTime(totalSec) {
            var s = Math.max(0, Math.floor(totalSec));
            var hrs = Math.floor(s / 3600);
            var mins = Math.floor((s % 3600) / 60);
            var secs = s % 60;
            if (hrs > 0) {
                return hrs + ':' + (mins < 10 ? '0' : '') + mins + ':' + (secs < 10 ? '0' : '') + secs;
            }
            return (mins < 10 ? '0' : '') + mins + ':' + (secs < 10 ? '0' : '') + secs;
        }

        function cleanSubtitleText(raw) {
            if (!raw) return '';
            var text = raw.replace(/\\[.*?\\]\\s*/g, '').trim();
            text = text.replace(/^\\s*|\\s*$/g, '');
            return text;
        }

        function processSubtitles() {
            var containers = document.querySelectorAll('.player-timedtext, .timed-text-container, [data-uia="player-timedtext"]');
            var rawText = '';

            for (var i = 0; i < containers.length; i++) {
                var c = containers[i];
                var spans = c.querySelectorAll('.player-timedtext-text-container, span');
                if (spans.length > 0) {
                    var lineParts = [];
                    for (var j = 0; j < spans.length; j++) {
                        var t = spans[j].innerText || spans[j].textContent || '';
                        if (t.trim()) lineParts.push(t.trim());
                    }
                    if (lineParts.length > 0) {
                        rawText = lineParts.join(' ');
                        break;
                    }
                } else if (c.innerText && c.innerText.trim()) {
                    rawText = c.innerText.trim();
                    break;
                }
            }

            var cleaned = cleanSubtitleText(rawText);
            if (!cleaned) return;

            var currentTime = getCurrentTimeSeconds();
            if (cleaned !== lastSubtitleText || Math.abs(currentTime - lastSubtitleTime) > 4.0) {
                lastSubtitleText = cleaned;
                lastSubtitleTime = currentTime;

                var payload = {
                    type: 'cue',
                    id: Date.now() + '_' + Math.floor(currentTime),
                    text: cleaned,
                    startTime: currentTime,
                    endTime: currentTime + 4.0,
                    formattedTime: formatTime(currentTime),
                    timestamp: Date.now() / 1000.0
                };

                try {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.subtitleStream) {
                        window.webkit.messageHandlers.subtitleStream.postMessage(payload);
                    }
                } catch(err) {
                    console.error('[NetflixNative] Failed to post subtitle message:', err);
                }
            }
        }

        function startObserving() {
            if (subtitleObserver) subtitleObserver.disconnect();
            subtitleObserver = new MutationObserver(function() {
                processSubtitles();
            });
            subtitleObserver.observe(document.body, { childList: true, subtree: true, characterData: true });
        }

        // Attach Seek and Playback APIs
        window.__netflixNativeSeek = function(targetSeconds) {
            var player = getNetflixPlayerAPI();
            var sid = getSessionId(player);
            if (player && sid) {
                try {
                    player.seek(sid, Math.floor(targetSeconds * 1000));
                    return true;
                } catch(e) {}
            }
            var video = getActiveVideo();
            if (video) {
                video.currentTime = targetSeconds;
                return true;
            }
            return false;
        };

        window.__netflixNativePlayPause = function() {
            var video = getActiveVideo();
            if (video) {
                if (video.paused) video.play();
                else video.pause();
            }
        };

        // Scroll-up listener to reveal Mac waterfall dialogue
        var scrollAccumulator = 0;
        var lastScrollTime = 0;
        window.addEventListener('wheel', function(e) {
            var now = Date.now();
            if (now - lastScrollTime > 1000) {
                scrollAccumulator = 0;
            }
            lastScrollTime = now;

            // Detect 2-finger scroll up / wheel up when watching video
            if (e.deltaY < -20 && window.location.pathname.indexOf('/watch/') !== -1) {
                scrollAccumulator += Math.abs(e.deltaY);
                if (scrollAccumulator > 80) {
                    scrollAccumulator = 0;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.subtitleStream) {
                        window.webkit.messageHandlers.subtitleStream.postMessage({ type: 'toggleOverlay' });
                    }
                }
            }
        }, { passive: true });

        // Hotkey 'D' to toggle overlay
        window.addEventListener('keydown', function(e) {
            var active = document.activeElement;
            var isInput = active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);
            if (!isInput && (e.key === 'd' || e.key === 'D') && !e.metaKey && !e.ctrlKey && !e.altKey) {
                if (window.location.pathname.indexOf('/watch/') !== -1) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.subtitleStream) {
                        window.webkit.messageHandlers.subtitleStream.postMessage({ type: 'toggleOverlay' });
                    }
                }
            }
        }, true);

        // Track episode / URL changes
        var currentUrl = window.location.href;
        setInterval(function() {
            if (window.location.href !== currentUrl) {
                currentUrl = window.location.href;
                lastSubtitleText = '';
                lastSubtitleTime = 0;
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.subtitleStream) {
                    window.webkit.messageHandlers.subtitleStream.postMessage({
                        type: 'urlChanged',
                        url: currentUrl,
                        isWatch: currentUrl.indexOf('/watch/') !== -1
                    });
                }
            }
        }, 1000);

        startObserving();
    })();
    """
}
