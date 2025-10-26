/**
 * ViewerManager - Global manager for Babylon.js viewers
 *
 * Manages visibility and rendering of multiple 3D viewers to optimize performance.
 * AGGRESSIVE MODE: Keeps only 2 viewers CREATED at a time, disposes others completely.
 */

class ViewerManager {
  constructor() {
    this.viewers = new Map(); // canvasId -> { viewer, isVisible, lastVisibility }
    this.maxActiveViewers = 2;
    this.disposeTimeouts = new Map(); // canvasId -> timeout ID for delayed disposal
    this.DISPOSE_DELAY = 2000; // Wait 2s before disposing invisible viewer
    console.log('[ViewerManager] ✅ Initialized (AGGRESSIVE MODE)');
  }

  /**
   * Register a viewer
   */
  registerViewer(canvasId, viewer) {
    // Cancel any pending disposal for this viewer
    if (this.disposeTimeouts.has(canvasId)) {
      clearTimeout(this.disposeTimeouts.get(canvasId));
      this.disposeTimeouts.delete(canvasId);
    }

    this.viewers.set(canvasId, {
      viewer: viewer,
      isVisible: false,
      lastVisibility: 0
    });
    console.log(`[ViewerManager] ✅ Registered viewer: ${canvasId} (Total: ${this.viewers.size})`);
  }

  /**
   * Update visibility for a viewer
   */
  updateVisibility(canvasId, isVisible, visibleFraction) {
    const entry = this.viewers.get(canvasId);
    if (!entry) {
      console.warn(`[ViewerManager] Viewer not found: ${canvasId}`);
      return;
    }

    const wasVisible = entry.isVisible;
    entry.isVisible = isVisible;
    entry.lastVisibility = visibleFraction;

    // If visibility changed, rebalance active viewers
    if (wasVisible !== isVisible) {
      console.log(`[ViewerManager] ${canvasId} visibility changed: ${isVisible} (${(visibleFraction * 100).toFixed(1)}%)`);
      this.rebalanceViewers();
    }
  }

  /**
   * Rebalance active viewers - AGGRESSIVE MODE
   * Immediately disposes hidden viewers, delays disposal for recently hidden
   */
  rebalanceViewers() {
    // Get all visible viewers sorted by visibility fraction
    const visibleViewers = Array.from(this.viewers.entries())
      .filter(([_, entry]) => entry.isVisible)
      .sort((a, b) => b[1].lastVisibility - a[1].lastVisibility);

    // Get all currently hidden viewers
    const hiddenViewers = Array.from(this.viewers.entries())
      .filter(([_, entry]) => !entry.isVisible);

    console.log(`[ViewerManager] 🔄 Rebalancing: ${visibleViewers.length} visible, ${hiddenViewers.length} hidden, ${this.viewers.size} total`);

    // Resume top 2 most visible viewers
    const viewersToActivate = visibleViewers.slice(0, this.maxActiveViewers);
    const viewersToPause = visibleViewers.slice(this.maxActiveViewers);

    // Activate top 2 visible viewers
    viewersToActivate.forEach(([canvasId, entry]) => {
      // Cancel any pending disposal
      if (this.disposeTimeouts.has(canvasId)) {
        clearTimeout(this.disposeTimeouts.get(canvasId));
        this.disposeTimeouts.delete(canvasId);
      }

      if (entry.viewer.isPaused !== false || entry.viewer.isDisposed) {
        console.log(`[ViewerManager] ▶️ RESUMING: ${canvasId} (${(entry.lastVisibility * 100).toFixed(1)}% visible)`);
        entry.viewer.resume();
      }
    });

    // Pause excess visible viewers (soft pause)
    viewersToPause.forEach(([canvasId, entry]) => {
      if (entry.viewer.isPaused !== true && !entry.viewer.isDisposed) {
        console.log(`[ViewerManager] ⏸️ PAUSING (excess): ${canvasId}`);
        entry.viewer.pause();
      }

      // Schedule disposal after delay
      this.scheduleDisposal(canvasId, entry);
    });

    // Schedule disposal for all hidden viewers
    hiddenViewers.forEach(([canvasId, entry]) => {
      this.scheduleDisposal(canvasId, entry);
    });

    // Log active viewers
    const activeCount = Array.from(this.viewers.values())
      .filter(e => !e.viewer.isDisposed && !e.viewer.isPaused).length;
    const disposedCount = Array.from(this.viewers.values())
      .filter(e => e.viewer.isDisposed).length;

    console.log(`[ViewerManager] 📊 Status: ${activeCount} active, ${disposedCount} disposed, ${this.viewers.size} total`);
  }

  /**
   * Schedule disposal for a viewer (with delay to avoid thrashing)
   */
  scheduleDisposal(canvasId, entry) {
    // Don't schedule if already scheduled
    if (this.disposeTimeouts.has(canvasId)) {
      return;
    }

    // Don't dispose if already disposed
    if (entry.viewer.isDisposed) {
      return;
    }

    const timeoutId = setTimeout(() => {
      if (entry.viewer && entry.viewer.engine && !entry.viewer.isDisposed) {
        console.log(`[ViewerManager] 🗑️ DISPOSING: ${canvasId} (was invisible for ${this.DISPOSE_DELAY}ms)`);
        entry.viewer.dispose();
      }
      this.disposeTimeouts.delete(canvasId);
    }, this.DISPOSE_DELAY);

    this.disposeTimeouts.set(canvasId, timeoutId);
  }

  /**
   * Unregister a viewer (cleanup)
   */
  unregisterViewer(canvasId) {
    // Clear any pending disposal timeout
    if (this.disposeTimeouts.has(canvasId)) {
      clearTimeout(this.disposeTimeouts.get(canvasId));
      this.disposeTimeouts.delete(canvasId);
    }

    const entry = this.viewers.get(canvasId);
    if (entry && entry.viewer) {
      entry.viewer.pause();
    }
    this.viewers.delete(canvasId);
    console.log(`[ViewerManager] ❌ Unregistered viewer: ${canvasId}`);
  }

  /**
   * Get detailed status report (useful for debugging)
   */
  getStatus() {
    const status = {
      total: this.viewers.size,
      active: 0,
      paused: 0,
      disposed: 0,
      pendingDisposal: this.disposeTimeouts.size,
      viewers: []
    };

    this.viewers.forEach((entry, canvasId) => {
      const viewerStatus = {
        id: canvasId,
        isVisible: entry.isVisible,
        visibility: (entry.lastVisibility * 100).toFixed(1) + '%',
        isPaused: entry.viewer.isPaused || false,
        isDisposed: entry.viewer.isDisposed || false,
        hasEngine: !!entry.viewer.engine
      };

      if (entry.viewer.isDisposed) {
        status.disposed++;
      } else if (entry.viewer.isPaused) {
        status.paused++;
      } else {
        status.active++;
      }

      status.viewers.push(viewerStatus);
    });

    return status;
  }

  /**
   * Print detailed status to console
   */
  printStatus() {
    const status = this.getStatus();
    console.log('═══════════════════════════════════════════');
    console.log('📊 ViewerManager Status Report');
    console.log('═══════════════════════════════════════════');
    console.log(`Total Viewers:      ${status.total}`);
    console.log(`🟢 Active (rendering): ${status.active}`);
    console.log(`🟡 Paused:            ${status.paused}`);
    console.log(`🔴 Disposed:          ${status.disposed}`);
    console.log(`⏳ Pending Disposal:  ${status.pendingDisposal}`);
    console.log('───────────────────────────────────────────');
    status.viewers.forEach(v => {
      const emoji = v.isDisposed ? '🔴' : (v.isPaused ? '🟡' : '🟢');
      console.log(`${emoji} ${v.id}: visible=${v.isVisible} (${v.visibility}), engine=${v.hasEngine}`);
    });
    console.log('═══════════════════════════════════════════');
    return status;
  }
}

// Create global singleton instance
if (typeof window !== 'undefined') {
  window.viewerManager = new ViewerManager();
  console.log('[ViewerManager] ✅ Global instance created: window.viewerManager');
  console.log('[ViewerManager] 💡 Use viewerManager.printStatus() to check status');
}
