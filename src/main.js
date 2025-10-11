import Sortable from "./vendor/sortable.esm.js";

const tauriInvoke = typeof window.__TAURI__?.core?.invoke === "function" ? window.__TAURI__.core.invoke : null;

function clone(value) {
  if (typeof structuredClone === "function") {
    return structuredClone(value);
  }
  try {
    return JSON.parse(JSON.stringify(value));
  } catch {
    return value;
  }
}

const HOVER_DELAY_MS = 400;
const EDGE_SWITCH_DELAY_MS = 420;
const EDGE_ACTIVATION_PADDING = 80;
const TILE_WIDTH = 120;
const TILE_HEIGHT = 140;
const GRID_GAP = 28;

const state = {
  items: [],
  itemsPerPage: 24,
  currentPage: 0,
  gridSortables: [],
  groupSortables: new Map(),
  renderQueued: false,
  layout: { columns: 4, rows: 6 },
};

if (typeof globalThis !== "undefined") {
  globalThis.__LAUNCHPAD_STATE__ = state;
}
if (typeof window !== "undefined") {
  window.__LAUNCHPAD_STATE__ = state;
}

const dragState = {
  activeId: null,
  activeItem: null,
  fromGroupId: null,
  hoverCandidateId: null,
  hoverReady: false,
  hoverTimer: null,
  hoverElement: null,
  movingItem: null,
  isDragging: false,
  wasDraggingRecently: false,
  edgeTimer: null,
  pendingPage: null,
};

const elements = {
  launchpad: null,
  track: null,
  pagination: null,
  prevButton: null,
  nextButton: null,
  viewport: null,
};

function generateGroupId() {
  if (window.crypto?.randomUUID) {
    return window.crypto.randomUUID();
  }
  return `group-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function scheduleRender() {
  if (state.renderQueued) {
    return;
  }
  state.renderQueued = true;
  requestAnimationFrame(() => {
    state.renderQueued = false;
    render();
    attachSortables();
  });
}

function getPageCount() {
  if (!state.itemsPerPage) {
    return 1;
  }
  return Math.max(1, Math.ceil(state.items.length / state.itemsPerPage));
}

function getPageBounds(pageIndex) {
  const start = pageIndex * state.itemsPerPage;
  return { start, end: start + state.itemsPerPage };
}

function locateItemById(id) {
  for (let index = 0; index < state.items.length; index += 1) {
    const item = state.items[index];
    const pageIndex = Math.floor(index / state.itemsPerPage);
    if (item.id === id) {
      return { context: "grid", index, pageIndex, item };
    }
    if (item.type === "group") {
      const innerIndex = item.apps.findIndex((app) => app.id === id);
      if (innerIndex !== -1) {
        return {
          context: "group",
          index: innerIndex,
          groupIndex: index,
          pageIndex,
          group: item,
          item: item.apps[innerIndex],
        };
      }
    }
  }
  return null;
}

function createAppItem(app) {
  return {
    type: "app",
    id: app.path,
    name: app.name,
    path: app.path,
    icon: app.icon,
  };
}

function ensureGroupLabel(group) {
  if (!group.label) {
    group.label = `Collection (${group.apps.length})`;
    return;
  }
  group.label = group.label.replace(/\(.*\)$/, `(${group.apps.length})`);
}

function clearHoverState() {
  if (dragState.hoverTimer) {
    clearTimeout(dragState.hoverTimer);
    dragState.hoverTimer = null;
  }
  if (dragState.hoverElement) {
    dragState.hoverElement.classList.remove("dropping-target");
    dragState.hoverElement = null;
  }
  dragState.hoverCandidateId = null;
  dragState.hoverReady = false;
}

function cancelEdgeSwitch() {
  if (dragState.edgeTimer) {
    clearTimeout(dragState.edgeTimer);
    dragState.edgeTimer = null;
  }
  dragState.pendingPage = null;
}

function considerationForEdgeSwitch(evt) {
  if (!dragState.isDragging) {
    cancelEdgeSwitch();
    return;
  }
  const pointer = evt?.originalEvent;
  if (!pointer || typeof pointer.clientX !== "number") {
    cancelEdgeSwitch();
    return;
  }
  const withinLeft = pointer.clientX <= EDGE_ACTIVATION_PADDING;
  const withinRight = pointer.clientX >= window.innerWidth - EDGE_ACTIVATION_PADDING;
  if (!withinLeft && !withinRight) {
    cancelEdgeSwitch();
    return;
  }
  const targetPage = withinLeft ? state.currentPage - 1 : state.currentPage + 1;
  if (targetPage < 0 || targetPage >= getPageCount()) {
    cancelEdgeSwitch();
    return;
  }
  if (dragState.pendingPage === targetPage) {
    return;
  }
  cancelEdgeSwitch();
  dragState.pendingPage = targetPage;
  dragState.edgeTimer = setTimeout(() => {
    setCurrentPage(targetPage);
    cancelEdgeSwitch();
  }, EDGE_SWITCH_DELAY_MS);
}

function resetDragState() {
  clearHoverState();
  cancelEdgeSwitch();
  dragState.activeId = null;
  dragState.activeItem = null;
  dragState.fromGroupId = null;
  dragState.movingItem = null;
  dragState.isDragging = false;
  dragState.wasDraggingRecently = true;
  setTimeout(() => {
    dragState.wasDraggingRecently = false;
  }, 120);
}

function applyPageTransform() {
  if (!elements.track) {
    return;
  }
  const pageCount = getPageCount();
  if (state.currentPage >= pageCount) {
    state.currentPage = Math.max(0, pageCount - 1);
  }
  elements.track.style.transform = `translateX(-${state.currentPage * 100}%)`;
  if (elements.prevButton) {
    elements.prevButton.disabled = state.currentPage === 0;
  }
  if (elements.nextButton) {
    elements.nextButton.disabled = state.currentPage >= pageCount - 1;
  }
  updatePagination(pageCount);
}

function updatePagination(pageCount) {
  if (!elements.pagination) {
    return;
  }
  elements.pagination.innerHTML = "";
  for (let i = 0; i < pageCount; i += 1) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "pagination-dot";
    if (i === state.currentPage) {
      button.classList.add("is-active");
      button.setAttribute("aria-current", "true");
    }
    button.dataset.pageIndex = String(i);
    button.title = `Go to page ${i + 1}`;
    button.addEventListener("click", () => setCurrentPage(i));
    elements.pagination.appendChild(button);
  }
}

function setCurrentPage(nextPage) {
  const pageCount = getPageCount();
  const clamped = Math.max(0, Math.min(nextPage, pageCount - 1));
  if (clamped === state.currentPage) {
    return;
  }
  state.currentPage = clamped;
  applyPageTransform();
}

function createFallbackIcon(name) {
  const letter = (name || "?").trim().charAt(0).toUpperCase() || "?";
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128" preserveAspectRatio="xMidYMid meet"><defs><linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#667eea"/><stop offset="100%" stop-color="#764ba2"/></linearGradient></defs><rect rx="24" ry="24" width="128" height="128" fill="url(#grad)"/><text x="50%" y="58%" dominant-baseline="middle" text-anchor="middle" font-size="64" font-family="SF Pro Display, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" fill="#ffffff" opacity="0.88">${letter}</text></svg>`;
  return `data:image/svg+xml;base64,${btoa(svg)}`;
}

function applyIcon(img, icon, name) {
  img.decoding = "async";
  img.src = icon;
  img.alt = name;
  img.addEventListener(
    "error",
    () => {
      if (img.dataset.fallback === "1") {
        return;
      }
      img.dataset.fallback = "1";
      img.src = createFallbackIcon(name);
    },
    { once: true },
  );
}

function render() {
  if (!elements.track || !elements.viewport) {
    return;
  }
  const pageCount = getPageCount();
  elements.track.innerHTML = "";
  for (let pageIndex = 0; pageIndex < pageCount; pageIndex += 1) {
    const page = document.createElement("section");
    page.className = "launchpad-page";
    page.dataset.pageIndex = String(pageIndex);

    const grid = document.createElement("div");
    grid.className = "launchpad-grid";
    grid.dataset.pageIndex = String(pageIndex);
    grid.style.setProperty("--columns", state.layout.columns);
    grid.style.setProperty("--rows", state.layout.rows);

    const bounds = getPageBounds(pageIndex);
    for (let idx = bounds.start; idx < bounds.end; idx += 1) {
      const item = state.items[idx];
      if (!item) {
        break;
      }
      const tile = document.createElement("div");
      tile.className = "app-item";
      tile.dataset.itemId = item.id;
      tile.dataset.type = item.type;
      tile.dataset.context = "grid";
      tile.dataset.pageIndex = String(pageIndex);
      tile.dataset.globalIndex = String(idx);
      tile.addEventListener("click", (evt) => handleTileClick(evt, item));

      if (item.type === "app") {
        const iconWrapper = document.createElement("div");
        iconWrapper.className = "app-icon";
        const img = document.createElement("img");
        applyIcon(img, item.icon, item.name);
        iconWrapper.appendChild(img);
        tile.appendChild(iconWrapper);

        const label = document.createElement("div");
        label.className = "app-name";
        label.textContent = item.name;
        tile.appendChild(label);
      } else {
        ensureGroupLabel(item);
        const folder = document.createElement("div");
        folder.className = "group-item";
        const stack = document.createElement("div");
        stack.className = "group-stack";
        stack.dataset.groupId = item.id;
        stack.dataset.pageIndex = String(pageIndex);
        item.apps.slice(0, 4).forEach((app) => {
          const cell = document.createElement("div");
          cell.className = "group-app";
          cell.dataset.itemId = app.id;
          cell.dataset.type = "app";
          cell.dataset.context = "group";
          cell.dataset.groupId = item.id;
          const img = document.createElement("img");
          applyIcon(img, app.icon, app.name);
          cell.appendChild(img);
          stack.appendChild(cell);
        });
        folder.appendChild(stack);
        tile.appendChild(folder);

        const label = document.createElement("div");
        label.className = "app-name";
        label.textContent = item.label;
        tile.appendChild(label);
      }

      grid.appendChild(tile);
    }

    page.appendChild(grid);
    elements.track.appendChild(page);
  }
  applyPageTransform();
}

function detachSortables() {
  state.gridSortables.forEach((sortable) => sortable.destroy());
  state.gridSortables = [];
  state.groupSortables.forEach((sortable) => sortable.destroy());
  state.groupSortables.clear();
}

function removeItemFromState(itemId) {
  const located = locateItemById(itemId);
  if (!located) {
    return null;
  }
  if (located.context === "grid") {
    return state.items.splice(located.index, 1)[0];
  }
  const group = state.items[located.groupIndex];
  const removed = group.apps.splice(located.index, 1)[0];
  if (group.apps.length <= 1) {
    const remaining = group.apps.slice();
    state.items.splice(located.groupIndex, 1, ...remaining);
  } else {
    ensureGroupLabel(group);
  }
  return removed;
}

function insertItemAtGlobalIndex(item, index) {
  const clamped = Math.max(0, Math.min(index, state.items.length));
  state.items.splice(clamped, 0, item);
}

function handleGroupHoverDrop(targetId, sourceItem) {
  const targetLocation = locateItemById(targetId);
  if (!targetLocation || targetLocation.context !== "grid") {
    return false;
  }
  const targetItem = state.items[targetLocation.index];
  if (!targetItem || targetItem.type !== "app") {
    return false;
  }
  const sourceLocation = locateItemById(sourceItem.id);
  if (sourceLocation && sourceLocation.context === "grid") {
    state.items.splice(sourceLocation.index, 1);
  } else if (sourceLocation && sourceLocation.context === "group") {
    const group = state.items[sourceLocation.groupIndex];
    group.apps.splice(sourceLocation.index, 1);
    if (group.apps.length <= 1) {
      const remaining = group.apps.slice();
      state.items.splice(sourceLocation.groupIndex, 1, ...remaining);
    } else {
      ensureGroupLabel(group);
    }
  }
  const removedTarget = state.items.splice(targetLocation.index, 1)[0];
  const group = {
    type: "group",
    id: generateGroupId(),
    label: "",
    apps: [removedTarget, sourceItem],
  };
  ensureGroupLabel(group);
  state.items.splice(targetLocation.index, 0, group);
  return true;
}

function attachSortables() {
  detachSortables();
  document.querySelectorAll(".launchpad-grid").forEach((grid) => {
    const sortable = new Sortable(grid, {
      animation: 220,
      dragClass: "sortable-drag",
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      group: { name: "launchpad", pull: true, put: true },
      onStart: (evt) => {
        dragState.isDragging = true;
        const itemId = evt.item.dataset.itemId;
        dragState.activeId = itemId;
  const located = locateItemById(itemId);
  dragState.activeItem = located ? clone(located.item) : null;
        dragState.fromGroupId = evt.item.dataset.groupId || null;
      },
      onMove: (evt) => {
        considerationForEdgeSwitch(evt);
        const related = evt.related;
        if (!related?.dataset) {
          clearHoverState();
          return true;
        }
        if (related.dataset.context !== "grid" || related.dataset.type !== "app" || related.dataset.itemId === dragState.activeId) {
          clearHoverState();
          return true;
        }
        if (dragState.hoverCandidateId !== related.dataset.itemId) {
          clearHoverState();
          dragState.hoverCandidateId = related.dataset.itemId;
          dragState.hoverElement = related;
          dragState.hoverTimer = setTimeout(() => {
            dragState.hoverReady = true;
            dragState.hoverElement?.classList.add("dropping-target");
          }, HOVER_DELAY_MS);
        }
        return true;
      },
      onUpdate: (evt) => {
        const pageIndex = Number(evt.from.dataset.pageIndex);
        const base = pageIndex * state.itemsPerPage;
        const oldIndex = base + evt.oldIndex;
        const newIndex = base + evt.newIndex;
        if (oldIndex === newIndex) {
          return;
        }
        const [item] = state.items.splice(oldIndex, 1);
        const insertionIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
        state.items.splice(insertionIndex, 0, item);
        scheduleRender();
      },
      onRemove: (evt) => {
        const itemId = evt.item.dataset.itemId;
        dragState.movingItem = removeItemFromState(itemId);
      },
      onAdd: (evt) => {
        if (!dragState.movingItem) {
          return;
        }
        const pageIndex = Number(evt.to.dataset.pageIndex);
        const base = pageIndex * state.itemsPerPage;
        const insertIndex = base + evt.newIndex;
        insertItemAtGlobalIndex(dragState.movingItem, insertIndex);
        dragState.movingItem = null;
        scheduleRender();
      },
      onEnd: () => {
        if (dragState.hoverReady && dragState.hoverCandidateId && dragState.activeItem?.type === "app") {
          const handled = handleGroupHoverDrop(dragState.hoverCandidateId, dragState.activeItem);
          if (handled) {
            scheduleRender();
          }
        }
        clearHoverState();
        dragState.isDragging = false;
        scheduleRender();
        resetDragState();
      },
    });
    state.gridSortables.push(sortable);
  });

  document.querySelectorAll(".group-stack").forEach((stack) => {
    const groupId = stack.dataset.groupId;
    const sortable = new Sortable(stack, {
      animation: 180,
      dragClass: "sortable-drag",
      ghostClass: "sortable-ghost",
      chosenClass: "sortable-chosen",
      group: { name: "launchpad", pull: true, put: true },
      onStart: (evt) => {
        dragState.isDragging = true;
        const itemId = evt.item.dataset.itemId;
        dragState.activeId = itemId;
  const located = locateItemById(itemId);
  dragState.activeItem = located ? clone(located.item) : null;
        dragState.fromGroupId = groupId;
      },
      onUpdate: (evt) => {
        const group = state.items.find((item) => item.id === groupId);
        if (!group) {
          return;
        }
        const [moved] = group.apps.splice(evt.oldIndex, 1);
        group.apps.splice(evt.newIndex, 0, moved);
        ensureGroupLabel(group);
        scheduleRender();
      },
      onRemove: (evt) => {
        const groupIndex = state.items.findIndex((item) => item.id === groupId);
        const group = groupIndex === -1 ? null : state.items[groupIndex];
        if (!group) {
          return;
        }
        const removed = group.apps.splice(evt.oldIndex, 1)[0];
        dragState.movingItem = removed;
        if (group.apps.length <= 1) {
          const remaining = group.apps.slice();
          state.items.splice(groupIndex, 1, ...remaining);
        } else {
          ensureGroupLabel(group);
        }
      },
      onAdd: (evt) => {
        const group = state.items.find((item) => item.id === groupId);
        if (!group || !dragState.movingItem) {
          return;
        }
        const exists = group.apps.findIndex((app) => app.id === dragState.movingItem.id);
        if (exists !== -1) {
          group.apps.splice(exists, 1);
        }
        group.apps.splice(evt.newIndex, 0, dragState.movingItem);
        ensureGroupLabel(group);
        dragState.movingItem = null;
        scheduleRender();
      },
      onEnd: () => {
        dragState.isDragging = false;
        scheduleRender();
        resetDragState();
      },
    });
    state.groupSortables.set(groupId, sortable);
  });
}

function handleTileClick(evt, item) {
  evt.stopPropagation();
  if (dragState.isDragging || dragState.wasDraggingRecently) {
    return;
  }
  if (item.type === "app" && item.path) {
    (tauriInvoke ? tauriInvoke("launch_app", { path: item.path }) : Promise.resolve()).catch(() => undefined);
  }
}

function debounce(fn, wait = 150) {
  let timer = null;
  return (...args) => {
    if (timer) {
      clearTimeout(timer);
    }
    timer = setTimeout(() => {
      timer = null;
      fn(...args);
    }, wait);
  };
}

const recalculateLayout = debounce(() => {
  if (!elements.viewport) {
    return;
  }
  const box = elements.viewport.getBoundingClientRect();
  const columns = Math.max(3, Math.min(7, Math.floor(box.width / (TILE_WIDTH + GRID_GAP))));
  const rows = Math.max(2, Math.min(5, Math.floor(box.height / (TILE_HEIGHT + GRID_GAP))));
  const itemsPerPage = Math.max(1, columns * rows);
  if (
    itemsPerPage !== state.itemsPerPage ||
    columns !== state.layout.columns ||
    rows !== state.layout.rows
  ) {
    state.layout = { columns, rows };
    state.itemsPerPage = itemsPerPage;
    if (state.currentPage >= getPageCount()) {
      state.currentPage = Math.max(0, getPageCount() - 1);
    }
    scheduleRender();
  }
}, 120);

async function loadApplications() {
  if (tauriInvoke) {
    try {
      const apps = await tauriInvoke("get_installed_apps");
      state.items = Array.isArray(apps) ? apps.map(createAppItem) : [];
    } catch {
      state.items = [];
    }
  } else {
    const seed = [
      "Sample App",
      "Demo Tool",
      "Prototype",
      "Reference",
      "Sandbox",
      "Preview",
      "Insights",
      "Monitor",
    ];
  state.items = Array.from({ length: 40 }, (_, index) => {
      const name = seed[index % seed.length];
      return {
        type: "app",
        id: `sample-${index + 1}`,
        name: index < seed.length ? name : `${name} ${index + 1}`,
        path: "",
        icon: createFallbackIcon(name),
      };
    });
  }
  recalculateLayout();
  scheduleRender();
}

function bindNavigation() {
  elements.prevButton?.addEventListener("click", () => setCurrentPage(state.currentPage - 1));
  elements.nextButton?.addEventListener("click", () => setCurrentPage(state.currentPage + 1));
}

window.addEventListener("resize", recalculateLayout);

function exposeTestHarness() {
  const root = typeof globalThis !== "undefined" ? globalThis : window;
  if (tauriInvoke || typeof root === "undefined" || root.__LAUNCHPAD_TEST__) {
    return;
  }
  root.__LAUNCHPAD_TEST__ = {
    getState: () => ({
      items: state.items.map((item) =>
        item.type === "group"
          ? { type: "group", id: item.id, apps: item.apps.map((app) => app.id) }
          : { type: "app", id: item.id },
      ),
      currentPage: state.currentPage,
      itemsPerPage: state.itemsPerPage,
      pageCount: getPageCount(),
    }),
    reorder: (sourceId, globalIndex) => {
      const located = locateItemById(sourceId);
      if (!located || located.context !== "grid") {
        return false;
      }
      const [item] = state.items.splice(located.index, 1);
      const index = Math.max(0, Math.min(globalIndex, state.items.length));
      state.items.splice(index, 0, item);
      scheduleRender();
      return true;
    },
    createGroup: (sourceId, targetId) => {
      const source = locateItemById(sourceId);
      if (!source?.item) {
        return false;
      }
      const succeeded = handleGroupHoverDrop(targetId, source.item);
      if (succeeded) {
        scheduleRender();
      }
      return succeeded;
    },
  };
}

window.addEventListener("DOMContentLoaded", () => {
  elements.launchpad = document.getElementById("launchpad");
  elements.track = document.getElementById("carousel-track");
  elements.pagination = document.getElementById("pagination-dots");
  elements.prevButton = document.getElementById("nav-prev");
  elements.nextButton = document.getElementById("nav-next");
  elements.viewport = document.getElementById("carousel-viewport");
  bindNavigation();
  exposeTestHarness();
  loadApplications().catch(() => undefined);
});
