import Foundation

struct SubtitleScriptInjector {
    static let scriptSource = """
    (function() {
        if (window.__netflixSubtitleExtractorInstalled) return;
        window.__netflixSubtitleExtractorInstalled = true;

        var lastSubtitleText = '';
        var lastSubtitleTime = 0;
        var isSeekingInternal = false;
        var subtitleObserver = null;
        var videoElement = null;

        function getActiveVideo() {
            if (videoElement && document.body.contains(videoElement)) return videoElement;
            videoElement = document.querySelector('video');
            if (videoElement) {
                attachVideoListeners(videoElement);
            }
            return videoElement;
        }

        function attachVideoListeners(video) {
            if (video.__nativeListenersAttached) return;
            video.__nativeListenersAttached = true;

            video.addEventListener('seeking', function() {
                isSeekingInternal = true;
            });

            video.addEventListener('seeked', function() {
                isSeekingInternal = false;
                lastSubtitleText = '';
                var currentTime = getCurrentTimeSeconds();
                lastSubtitleTime = currentTime;
                postToNative({
                    type: 'seeked',
                    currentTime: currentTime
                });
            });
        }

        function getNetflixVideoPlayer() {
            try {
                if (window.netflix && window.netflix.appContext) {
                    var playerApp = window.netflix.appContext.getPlayerApp();
                    if (playerApp) {
                        var api = playerApp.getAPI();
                        if (api && api.videoPlayer) {
                            var sessionIds = api.videoPlayer.getAllPlayerSessionIds();
                            if (sessionIds && sessionIds.length > 0) {
                                var activeSessionId = sessionIds[sessionIds.length - 1];
                                return api.videoPlayer.getVideoPlayerBySessionId(activeSessionId);
                            }
                        }
                    }
                }
            } catch(e) {
                // Ignore API lookup errors
            }
            return null;
        }

        function getCurrentTimeSeconds() {
            var player = getNetflixVideoPlayer();
            if (player && typeof player.getCurrentTime === 'function') {
                try {
                    var ms = player.getCurrentTime();
                    if (ms && !isNaN(ms)) return ms / 1000.0;
                } catch(e) {}
            }
            var video = getActiveVideo();
            if (video && !isNaN(video.currentTime) && video.currentTime > 0) {
                return video.currentTime;
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

        function extractCleanSubtitles() {
            // Find root timed text container
            var root = document.querySelector('.player-timedtext') || 
                       document.querySelector('.timed-text-container') ||
                       document.querySelector('[data-uia="player-timedtext"]');
            if (!root) return null;

            // Target the discrete line containers
            var lineContainers = root.querySelectorAll('.player-timedtext-text-container');
            var collectedLines = [];

            if (lineContainers.length > 0) {
                for (var i = 0; i < lineContainers.length; i++) {
                    var container = lineContainers[i];
                    // Look for child spans or take the container's innerText
                    var textSpans = container.querySelectorAll('span');
                    if (textSpans.length > 0) {
                        // Gather leaf spans only (spans that do not contain other spans)
                        var leafTexts = [];
                        for (var j = 0; j < textSpans.length; j++) {
                            var span = textSpans[j];
                            if (span.children.length === 0) {
                                var txt = (span.innerText || span.textContent || '').trim();
                                if (txt && leafTexts.indexOf(txt) === -1) {
                                    leafTexts.push(txt);
                                }
                            }
                        }
                        if (leafTexts.length > 0) {
                            var lineStr = leafTexts.join(' ');
                            if (lineStr && collectedLines.indexOf(lineStr) === -1) {
                                collectedLines.push(lineStr);
                            }
                        }
                    } else {
                        var cText = (container.innerText || container.textContent || '').trim();
                        if (cText && collectedLines.indexOf(cText) === -1) {
                            collectedLines.push(cText);
                        }
                    }
                }
            } else {
                // Fallback for flat structure: grab leaf spans only
                var allSpans = root.querySelectorAll('span');
                var leafTexts = [];
                for (var k = 0; k < allSpans.length; k++) {
                    if (allSpans[k].children.length === 0) {
                        var sText = (allSpans[k].innerText || allSpans[k].textContent || '').trim();
                        if (sText && leafTexts.indexOf(sText) === -1) {
                            leafTexts.push(sText);
                        }
                    }
                }
                if (leafTexts.length > 0) {
                    collectedLines.push(leafTexts.join(' '));
                }
            }

            if (collectedLines.length === 0) return null;

            var fullText = collectedLines.join(' ').replace(/\\s+/g, ' ').trim();
            return cleanSubtitleText(fullText);
        }

        function processSubtitles() {
            if (isSeekingInternal) return;

            var cleaned = extractCleanSubtitles();
            if (!cleaned) return;

            var currentTime = getCurrentTimeSeconds();
            if (cleaned !== lastSubtitleText || Math.abs(currentTime - lastSubtitleTime) > 3.5) {
                lastSubtitleText = cleaned;
                lastSubtitleTime = currentTime;

                postToNative({
                    type: 'cue',
                    id: Date.now() + '_' + Math.floor(currentTime),
                    text: cleaned,
                    startTime: currentTime,
                    endTime: currentTime + 3.5,
                    formattedTime: formatTime(currentTime),
                    timestamp: Date.now() / 1000.0
                });
            }
        }

        function postToNative(payload) {
            try {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.subtitleStream) {
                    window.webkit.messageHandlers.subtitleStream.postMessage(payload);
                }
            } catch(err) {
                console.error('[NetflixNative] Message post error:', err);
            }
        }

        function startObserving() {
            if (subtitleObserver) subtitleObserver.disconnect();
            subtitleObserver = new MutationObserver(function() {
                processSubtitles();
            });
            subtitleObserver.observe(document.body, { childList: true, subtree: true, characterData: true });
        }

        var userSubtitlesVisible = true;
        var subtitleStyleElement = null;

        function updateSubtitleVisibility() {
            if (!subtitleStyleElement) {
                subtitleStyleElement = document.createElement('style');
                subtitleStyleElement.id = 'netflix-native-subtitle-toggle-style';
                document.head.appendChild(subtitleStyleElement);
            }
            if (userSubtitlesVisible) {
                subtitleStyleElement.textContent = '';
            } else {
                subtitleStyleElement.textContent = '.player-timedtext, .timed-text-container, [data-uia="player-timedtext"] { opacity: 0 !important; }';
            }
        }

        function ensureSubtitlesActive() {
            // Method 1: Cadence VideoPlayer API track selection
            try {
                var player = getNetflixVideoPlayer();
                if (player) {
                    var currentTrack = null;
                    if (typeof player.getTimedTextTrack === 'function') {
                        currentTrack = player.getTimedTextTrack();
                    }
                    if (!currentTrack || !currentTrack.trackId || currentTrack.trackId === 'none') {
                        if (typeof player.getTimedTextTracks === 'function' && typeof player.setTimedTextTrack === 'function') {
                            var tracks = player.getTimedTextTracks();
                            if (tracks && tracks.length > 0) {
                                var selectedTrack = tracks.find(function(t) {
                                    return t.bcp47 === 'en' || (t.language && t.language.toLowerCase().indexOf('english') !== -1);
                                }) || tracks[0];
                                
                                if (selectedTrack) {
                                    player.setTimedTextTrack(selectedTrack);
                                    return;
                                }
                            }
                        }
                    }
                }
            } catch(e) {
                console.warn('[NetflixNative] Cadence timed text track activation error:', e);
            }

            // Method 2: DOM UI interaction fallback (Open audio/subtitle menu if not selected)
            try {
                var subtitleContainer = document.querySelector('.player-timedtext, .timed-text-container');
                if (!subtitleContainer || !subtitleContainer.innerText) {
                    var audioSubButton = document.querySelector('button[data-uia="control-audio-subtitle"], button[aria-label*="Subtitles"], button[aria-label*="Audio"]');
                    if (audioSubButton) {
                        // Click to open menu if not already open
                        var menu = document.querySelector('[data-uia="audio-subtitle-controller"], .audio-subtitle-controller');
                        if (!menu) {
                            audioSubButton.click();
                            setTimeout(function() {
                                var foundTarget = null;
                                
                                // Look for subtitle column options
                                var allOptions = document.querySelectorAll('li, div[role="button"], button, [data-uia*="subtitle"]');
                                for (var i = 0; i < allOptions.length; i++) {
                                    var el = allOptions[i];
                                    var text = (el.innerText || el.textContent || '').trim();
                                    
                                    // Match "English" or "English (CC)" or "English [CC]"
                                    var isEnglishText = text === 'English' || text.indexOf('English (CC)') === 0 || text.indexOf('English [CC]') === 0;
                                    if (isEnglishText && text.indexOf('[Original]') === -1 && text.indexOf('Audio Description') === -1) {
                                        // Ensure it's under the Subtitles column (not Audio column)
                                        var parentCol = el.closest('.track-list, [data-uia*="subtitle"], div, ul');
                                        var prevHeader = el.parentElement ? el.parentElement.querySelector('h3, header, .header') : null;
                                        var isAudio = (prevHeader && prevHeader.innerText.indexOf('Audio') !== -1);
                                        
                                        if (!isAudio) {
                                            foundTarget = el;
                                            break;
                                        }
                                    }
                                }
                                
                                if (foundTarget) {
                                    foundTarget.click();
                                }
                                
                                // Close menu after selection
                                setTimeout(function() {
                                    var openMenu = document.querySelector('[data-uia="audio-subtitle-controller"], .audio-subtitle-controller');
                                    if (openMenu) {
                                        audioSubButton.click();
                                    }
                                }, 150);
                            }, 250);
                        }
                    }
                }
            } catch(err) {
                console.warn('[NetflixNative] DOM subtitle button click error:', err);
            }
        }



        // Programmatic Seeking API using Cadence VideoPlayer API (avoiding video.currentTime deadlock)
        window.__netflixNativeSeek = function(targetSeconds) {
            isSeekingInternal = true;
            lastSubtitleText = '';
            lastSubtitleTime = targetSeconds;

            try {
                var player = getNetflixVideoPlayer();
                if (player && typeof player.seek === 'function') {
                    player.seek(Math.floor(targetSeconds * 1000));
                    setTimeout(function() { isSeekingInternal = false; }, 800);
                    return true;
                }
            } catch(e) {
                console.warn('[NetflixNative] Cadence seek failed:', e);
            }

            // If Cadence player is unavailable, do NOT force video.currentTime to prevent FairPlay lockup
            setTimeout(function() { isSeekingInternal = false; }, 800);
            return false;
        };

        window.__netflixNativeSetSubtitlesVisible = function(visible) {
            userSubtitlesVisible = visible;
            updateSubtitleVisibility();
        };

        window.__netflixNativeToggleSubtitlesVisible = function() {
            userSubtitlesVisible = !userSubtitlesVisible;
            updateSubtitleVisibility();
            return userSubtitlesVisible;
        };

        window.__netflixNativePlayPause = function() {
            try {
                var player = getNetflixVideoPlayer();
                if (player) {
                    if (typeof player.isPaused === 'function' && player.isPaused()) {
                        if (typeof player.play === 'function') player.play();
                    } else if (typeof player.pause === 'function') {
                        player.pause();
                    }
                    return;
                }
            } catch(e) {}

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

            if (e.deltaY < -20 && window.location.pathname.indexOf('/watch/') !== -1) {
                scrollAccumulator += Math.abs(e.deltaY);
                if (scrollAccumulator > 80) {
                    scrollAccumulator = 0;
                    postToNative({ type: 'toggleOverlay' });
                }
            }
        }, { passive: true });

        // Hotkeys: 'D' for Dialogue Waterfall, 'C' / 'V' for On-Screen Subtitle Visibility Toggle
        window.addEventListener('keydown', function(e) {
            var active = document.activeElement;
            var isInput = active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);
            if (isInput) return;

            if ((e.key === 'd' || e.key === 'D') && !e.metaKey && !e.ctrlKey && !e.altKey) {
                if (window.location.pathname.indexOf('/watch/') !== -1) {
                    postToNative({ type: 'toggleOverlay' });
                }
            } else if ((e.key === 'c' || e.key === 'C' || e.key === 'v' || e.key === 'V') && !e.metaKey && !e.ctrlKey && !e.altKey) {
                if (window.location.pathname.indexOf('/watch/') !== -1) {
                    window.__netflixNativeToggleSubtitlesVisible();
                }
            }
        }, true);

        // URL change & subtitle track verification monitor
        var currentUrl = window.location.href;
        setInterval(function() {
            getActiveVideo();
            if (window.location.pathname.indexOf('/watch/') !== -1) {
                ensureSubtitlesActive();
            }

            if (window.location.href !== currentUrl) {
                currentUrl = window.location.href;
                lastSubtitleText = '';
                lastSubtitleTime = 0;
                postToNative({
                    type: 'urlChanged',
                    url: currentUrl,
                    isWatch: currentUrl.indexOf('/watch/') !== -1
                });
            }
        }, 1000);

        updateSubtitleVisibility();
        startObserving();
    })();
    """
}
