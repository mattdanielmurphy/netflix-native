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
                    var playerApp = (typeof window.netflix.appContext.getPlayerApp === 'function')
                        ? window.netflix.appContext.getPlayerApp()
                        : (window.netflix.appContext.state ? window.netflix.appContext.state.playerApp : null);
                    if (playerApp) {
                        var api = (typeof playerApp.getAPI === 'function') ? playerApp.getAPI() : null;
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

        var hasAutoSelectedSubtitles = false;
        var isSelectingSubtitles = false;

        function ensureSubtitlesActive() {
            if (hasAutoSelectedSubtitles || isSelectingSubtitles) return;

            // Method 1: Cadence VideoPlayer API track selection
            try {
                var player = getNetflixVideoPlayer();
                if (player) {
                    var currentTrack = null;
                    if (typeof player.getTimedTextTrack === 'function') {
                        currentTrack = player.getTimedTextTrack();
                    }
                    if (currentTrack && currentTrack.trackId && currentTrack.trackId !== 'none') {
                        hasAutoSelectedSubtitles = true;
                        return;
                    }
                    if (typeof player.getTimedTextTracks === 'function' && typeof player.setTimedTextTrack === 'function') {
                        var tracks = player.getTimedTextTracks();
                        if (tracks && tracks.length > 0) {
                            var selectedTrack = tracks.find(function(t) {
                                return t.bcp47 === 'en' || (t.language && t.language.toLowerCase().indexOf('english') !== -1);
                            }) || tracks[0];
                            
                            if (selectedTrack) {
                                player.setTimedTextTrack(selectedTrack);
                                hasAutoSelectedSubtitles = true;
                                return;
                            }
                        }
                    }
                }
            } catch(e) {
                console.warn('[NetflixNative] Cadence timed text track activation error:', e);
            }

            // Method 2: DOM UI interaction fallback (Open audio/subtitle menu if not selected)
            try {
                var audioSubButton = document.querySelector('button[data-uia="control-audio-subtitle"], button[aria-label*="Subtitles"], button[aria-label*="Audio"]');
                if (!audioSubButton) return;

                isSelectingSubtitles = true;
                audioSubButton.click();

                setTimeout(function() {
                    var foundTarget = null;
                    
                    var allOptions = document.querySelectorAll('li, div[role="button"], button, [data-uia*="subtitle"]');
                    for (var i = 0; i < allOptions.length; i++) {
                        var el = allOptions[i];
                        var text = (el.innerText || el.textContent || '').trim();
                        
                        var isEnglishText = text === 'English' || text.indexOf('English (CC)') === 0 || text.indexOf('English [CC]') === 0;
                        if (isEnglishText && text.indexOf('[Original]') === -1 && text.indexOf('Audio Description') === -1) {
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
                        hasAutoSelectedSubtitles = true;
                    }
                    
                    // Dismiss menu by pressing Escape or clicking video background
                    setTimeout(function() {
                        var escEvent = new KeyboardEvent('keydown', { key: 'Escape', keyCode: 27, which: 27, bubbles: true });
                        document.dispatchEvent(escEvent);

                        var video = getActiveVideo();
                        if (video) {
                            video.dispatchEvent(new MouseEvent('click', { bubbles: true }));
                        }

                        isSelectingSubtitles = false;
                    }, 200);
                }, 300);
            } catch(err) {
                isSelectingSubtitles = false;
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

        function simulateClick(element, x, y) {
            if (!element) return false;

            var rect = (typeof element.getBoundingClientRect === 'function') ? element.getBoundingClientRect() : null;
            var clientX = (typeof x === 'number') ? x : (rect ? (rect.left + rect.width / 2) : (window.innerWidth / 2));
            var clientY = (typeof y === 'number') ? y : (rect ? (rect.top + rect.height / 2) : (window.innerHeight / 2));

            var commonProps = {
                bubbles: true,
                cancelable: true,
                composed: true,
                view: window,
                detail: 1,
                clientX: clientX,
                clientY: clientY,
                screenX: clientX,
                screenY: clientY,
                button: 0,
                buttons: 1
            };

            // 1. Pointer Down
            try {
                var pDown = new PointerEvent('pointerdown', Object.assign({}, commonProps, {
                    pointerId: 1,
                    pointerType: 'mouse',
                    isPrimary: true
                }));
                element.dispatchEvent(pDown);
            } catch(e) {}

            // 2. Mouse Down
            try {
                element.dispatchEvent(new MouseEvent('mousedown', commonProps));
            } catch(e) {}

            // 3. Pointer Up
            try {
                var pUp = new PointerEvent('pointerup', Object.assign({}, commonProps, {
                    pointerId: 1,
                    pointerType: 'mouse',
                    isPrimary: true,
                    buttons: 0
                }));
                element.dispatchEvent(pUp);
            } catch(e) {}

            // 4. Mouse Up
            try {
                element.dispatchEvent(new MouseEvent('mouseup', Object.assign({}, commonProps, { buttons: 0 })));
            } catch(e) {}

            // 5. Click
            try {
                element.dispatchEvent(new MouseEvent('click', Object.assign({}, commonProps, { buttons: 0 })));
            } catch(e) {}

            // 6. Native .click()
            if (typeof element.click === 'function') {
                try {
                    element.click();
                } catch(e) {}
            }

            return true;
        }

        function isVisibleElement(el) {
            if (!el) return false;
            var r = (typeof el.getBoundingClientRect === 'function') ? el.getBoundingClientRect() : null;
            if (!r || (r.width === 0 && r.height === 0)) return false;
            try {
                var style = window.getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false;
            } catch(e) {}
            return true;
        }

        function findAndClickPlayButton() {
            var width = window.innerWidth;
            var height = window.innerHeight;
            var centerX = width / 2;
            var centerY = height / 2;

            // 1. Direct hit-test around center of viewport
            var centerHitPoints = [
                { x: centerX, y: centerY },
                { x: centerX, y: centerY - 30 },
                { x: centerX, y: centerY + 30 },
                { x: centerX - 30, y: centerY },
                { x: centerX + 30, y: centerY },
                { x: centerX, y: centerY - 60 },
                { x: centerX, y: centerY + 60 }
            ];

            for (var i = 0; i < centerHitPoints.length; i++) {
                var pt = centerHitPoints[i];
                var hit = document.elementFromPoint(pt.x, pt.y);
                if (hit && hit.tagName !== 'VIDEO' && hit !== document.body && hit !== document.documentElement) {
                    // Ignore subtitle container if hit
                    if (hit.closest && hit.closest('.player-timedtext, .timed-text-container, [data-uia="player-timedtext"]')) {
                        continue;
                    }

                    // Check for button or role="button" or play/resume attribute
                    var btn = hit.closest ? hit.closest('button, [role="button"], [data-uia*="play"], [data-uia*="resume"], [data-uia*="continue"], [aria-label*="play" i], [aria-label*="resume" i]') : null;
                    if (btn && isVisibleElement(btn)) {
                        var br = btn.getBoundingClientRect();
                        simulateClick(btn, br.left + br.width / 2, br.top + br.height / 2);
                        if (hit !== btn) simulateClick(hit, pt.x, pt.y);
                        return true;
                    }

                    // Check if hit has or is an SVG (the play icon)
                    var svg = (hit.tagName && hit.tagName.toLowerCase() === 'svg') ? hit : ((hit.closest ? hit.closest('svg') : null) || (hit.querySelector ? hit.querySelector('svg') : null));
                    if (svg) {
                        var container = (hit.closest ? hit.closest('button, [role="button"], a, div') : null) || hit;
                        if (isVisibleElement(container)) {
                            var cr = container.getBoundingClientRect();
                            simulateClick(container, cr.left + cr.width / 2, cr.top + cr.height / 2);
                            if (hit !== container) simulateClick(hit, pt.x, pt.y);
                            return true;
                        }
                    }

                    // Check if hit is an overlay container within the center region
                    var hr = hit.getBoundingClientRect();
                    var hitDist = Math.hypot(hr.left + hr.width / 2 - centerX, hr.top + hr.height / 2 - centerY);
                    if (hitDist < Math.min(width, height) * 0.4 && isVisibleElement(hit)) {
                        simulateClick(hit, pt.x, pt.y);
                        return true;
                    }
                }
            }

            // 2. Search known Netflix play and resume selectors
            var selectors = [
                '[data-uia="play-button"]',
                '[data-uia="watch-video-play-button"]',
                '[data-uia="player-resume"]',
                '[data-uia="interrupt-autoplay-continue"]',
                '[data-uia*="play-button"]',
                '[data-uia*="player-play"]',
                '[data-uia*="resume"]',
                '[data-uia*="continue"]',
                'button[aria-label*="Play" i]',
                'button[aria-label*="Resume" i]',
                'button[aria-label*="Continue" i]',
                '[role="button"][aria-label*="Play" i]',
                '[role="button"][aria-label*="Resume" i]',
                '.button-nfplayerPlay',
                '.nf-player-play',
                'button[data-uia="control-play-pause-play"]'
            ];

            var candidates = document.querySelectorAll(selectors.join(', '));
            var bestCandidate = null;
            var minDistance = Infinity;

            for (var k = 0; k < candidates.length; k++) {
                var el = candidates[k];
                if (isVisibleElement(el)) {
                    var rect = el.getBoundingClientRect();
                    var elX = rect.left + rect.width / 2;
                    var elY = rect.top + rect.height / 2;
                    var dist = Math.hypot(elX - centerX, elY - centerY);
                    if (dist < minDistance) {
                        minDistance = dist;
                        bestCandidate = { element: el, x: elX, y: elY };
                    }
                }
            }

            if (bestCandidate) {
                simulateClick(bestCandidate.element, bestCandidate.x, bestCandidate.y);
                return true;
            }

            return false;
        }

        function findAndClickPauseButton() {
            var selectors = [
                'button[data-uia="control-play-pause-pause"]',
                'button[data-uia="control-play-pause"]',
                'button[aria-label*="Pause" i]',
                '[role="button"][aria-label*="Pause" i]'
            ];
            for (var i = 0; i < selectors.length; i++) {
                var btn = document.querySelector(selectors[i]);
                if (btn && isVisibleElement(btn)) {
                    var r = btn.getBoundingClientRect();
                    simulateClick(btn, r.left + r.width / 2, r.top + r.height / 2);
                    return true;
                }
            }
            return false;
        }

        window.__netflixNativeHandlePlayPause = function() {
            var video = getActiveVideo();
            var player = getNetflixVideoPlayer();

            // Determine if content is currently considered playing or paused
            var isPaused = true;
            if (player && typeof player.isPaused === 'function') {
                isPaused = player.isPaused();
            } else if (video) {
                isPaused = video.paused;
            }

            // Check if there is an on-screen play button / overlay
            var clickedPlayBtn = findAndClickPlayButton();

            if (clickedPlayBtn) {
                // Clicking the on-screen play button triggered Netflix's UI resume handler.
                // Re-check after 150ms to ensure player state matches
                setTimeout(function() {
                    var p = getNetflixVideoPlayer();
                    if (p && typeof p.isPaused === 'function' && p.isPaused()) {
                        if (typeof p.play === 'function') {
                            try { p.play(); } catch(e) {}
                        }
                    }
                }, 150);
                return;
            }

            // If no play button was clicked:
            if (isPaused) {
                // Resume playback: try Cadence player API first
                if (player && typeof player.play === 'function') {
                    try {
                        player.play();
                        return;
                    } catch(e) {}
                }
                // Fallback to active video
                if (video && video.paused) {
                    try { video.play(); } catch(e) {}
                }
            } else {
                // Pause playback: try pause button or Cadence player API
                var clickedPauseBtn = findAndClickPauseButton();
                if (!clickedPauseBtn) {
                    if (player && typeof player.pause === 'function') {
                        try {
                            player.pause();
                            return;
                        } catch(e) {}
                    }
                    if (video && !video.paused) {
                        try { video.pause(); } catch(e) {}
                    }
                }
            }
        };

        window.__netflixNativePause = function() {
            var player = getNetflixVideoPlayer();
            if (player && typeof player.pause === 'function') {
                try {
                    player.pause();
                    return;
                } catch(e) {}
            }
            findAndClickPauseButton();
            var video = getActiveVideo();
            if (video && !video.paused) {
                try { video.pause(); } catch(e) {}
            }
        };

        window.__netflixNativePlayPause = window.__netflixNativeHandlePlayPause;

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
                hasAutoSelectedSubtitles = false;
                isSelectingSubtitles = false;
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

