import Sortable from "./vendor/sortable.esm.js";

const { invoke } = window.__TAURI__.core;

const HOVER_DELAY_MS = 450;

const state = {
  items: [],
  gridSortable: null,
  groupSortables: new Map(),
  renderQueued: false,
};

const dragState = {
  activeId: null,
  activeItem: null,
  fromGroupId: null,
  movingItem: null,
  removedIndex: null,
  hoverCandidateId: null,
  hoverReady: false,
  hoverTimer: null,
  hoverElement: null,
  stateHandled: false,
  needsRender: false,
};

function generateGroupId() {
  if (window.crypto && window.crypto.randomUUID) {
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

function locateItemById(id) {
  for (let i = 0; i < state.items.length; i += 1) {
    const item = state.items[i];
    if (item.id === id) {
      return { context: "grid", index: i, item };
    }
    if (item.type === "group") {
      const index = item.apps.findIndex((app) => app.id === id);
      if (index !== -1) {
        return { context: "group", index, groupIndex: i, group: item, item: item.apps[index] };
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
    iconLoaded: false,
  };
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

function resetDragState() {
  clearHoverState();
  dragState.activeId = null;
  dragState.activeItem = null;
  dragState.fromGroupId = null;
  dragState.movingItem = null;
  dragState.removedIndex = null;
  dragState.stateHandled = false;
  dragState.needsRender = false;
}

function ensureGroupLabel(group) {
  if (!group.label) {
    group.label = `Collection (${group.apps.length})`;
  } else {
    group.label = group.label.replace(/\(.*\)$/, `(${group.apps.length})`);
  }
}

function render() {
  const grid = document.getElementById("app-grid");
  grid.innerHTML = "";
  state.items.forEach((item, index) => {
    const tile = document.createElement("div");
    tile.className = "app-item";
    tile.dataset.itemId = item.id;
    tile.dataset.type = item.type;
    tile.dataset.context = "grid";
    tile.dataset.index = String(index);
    if (item.type === "app") {
      const iconWrapper = document.createElement("div");
      iconWrapper.className = "app-icon";
      const img = document.createElement("img");
      img.alt = item.name;
      if (item.iconLoaded) {
        img.src = item.icon;
      } else {
        // Placeholder or loading state
        img.src = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjQiIGhlaWdodD0iNjQiIHZpZXdCb3g9IjAgMCA2NCA2NCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiBmaWxsPSIjRjNGNEY2Ii8+Cjx0ZXh0IHg9IjMyIiB5PSIzMiIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zNWVtIiBmaWxsPSIjOUI5QkE0IiBmb250LXNpemU9IjEyIj5BcHA8L3RleHQ+Cjwvc3ZnPg==";
        // Load icon asynchronously
        setTimeout(() => {
          img.src = item.icon;
          item.iconLoaded = true;
        }, 0);
      }
      iconWrapper.appendChild(img);
      tile.appendChild(iconWrapper);
      const label = document.createElement("div");
      label.className = "app-name";
      label.textContent = item.name;
      tile.appendChild(label);
      tile.addEventListener("dblclick", () => {
        invoke("launch_app", { path: item.path }).catch(() => undefined);
      });
    } else {
      ensureGroupLabel(item);
      const folder = document.createElement("div");
      folder.className = "group-item";
      const stack = document.createElement("div");
      stack.className = "group-stack";
      stack.dataset.groupId = item.id;
      item.apps.forEach((app) => {
        const cell = document.createElement("div");
        cell.className = "group-app";
        cell.dataset.itemId = app.id;
        cell.dataset.type = "app";
        cell.dataset.context = "group";
        cell.dataset.groupId = item.id;
        const img = document.createElement("img");
        img.src = app.icon;
        img.alt = app.name;
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
  });
}

function attachSortables() {
  const grid = document.getElementById("app-grid");
  if (state.gridSortable) {
    state.gridSortable.destroy();
  }
  state.groupSortables.forEach((sortable) => sortable.destroy());
  state.groupSortables.clear();
  state.gridSortable = new Sortable(grid, {
    animation: 200,
    dragClass: "sortable-drag",
    ghostClass: "sortable-ghost",
    chosenClass: "sortable-chosen",
    group: { name: "launchpad", pull: true, put: true },
    onStart: (evt) => {
      const itemId = evt.item.dataset.itemId;
      dragState.activeId = itemId;
      const located = locateItemById(itemId);
      dragState.activeItem = located ? JSON.parse(JSON.stringify(located.item)) : null;
      dragState.fromGroupId = evt.item.dataset.groupId || null;
      dragState.removedIndex = evt.oldIndex;
    },
    onMove: (evt) => {
      const related = evt.related;
      if (!related || !related.dataset) {
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
          if (dragState.hoverElement) {
            dragState.hoverElement.classList.add("dropping-target");
          }
        }, HOVER_DELAY_MS);
      }
      return true;
    },
    onEnd: (evt) => {
      if (dragState.hoverReady && dragState.hoverCandidateId && dragState.activeItem && dragState.activeItem.type === "app") {
        const targetIndex = state.items.findIndex((item) => item.id === dragState.hoverCandidateId);
        const targetItem = targetIndex !== -1 ? state.items[targetIndex] : null;
        if (targetItem && targetItem.type === "app") {
          const source = dragState.movingItem || dragState.activeItem;
          const sourceId = source.id;
          if (dragState.movingItem) {
            dragState.movingItem = null;
          }
          const sourceIndex = state.items.findIndex((item) => item.id === sourceId);
          if (sourceIndex !== -1) {
            state.items.splice(sourceIndex, 1);
          }
          const targetRemoved = state.items.splice(targetIndex, 1)[0];
          const group = {
            type: "group",
            id: generateGroupId(),
            label: `Collection (2)`,
            apps: [targetRemoved, source],
          };
          state.items.splice(targetIndex, 0, group);
          dragState.stateHandled = true;
          dragState.needsRender = true;
        }
      } else if (!dragState.stateHandled) {
        if (evt.oldIndex !== evt.newIndex && dragState.activeItem) {
          const item = state.items.splice(evt.oldIndex, 1)[0];
          state.items.splice(evt.newIndex, 0, item);
          dragState.needsRender = true;
        }
      }
      clearHoverState();
      if (dragState.needsRender) {
        scheduleRender();
      }
      resetDragState();
    },
    onRemove: (evt) => {
      const removed = state.items.splice(evt.oldIndex, 1)[0];
      dragState.movingItem = removed;
      dragState.stateHandled = true;
      dragState.needsRender = true;
    },
    onAdd: (evt) => {
      if (dragState.movingItem) {
        state.items.splice(evt.newIndex, 0, dragState.movingItem);
        dragState.movingItem = null;
        dragState.stateHandled = true;
        dragState.needsRender = true;
      }
    },
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
        const itemId = evt.item.dataset.itemId;
        dragState.activeId = itemId;
        const located = locateItemById(itemId);
        dragState.activeItem = located ? JSON.parse(JSON.stringify(located.item)) : null;
        dragState.fromGroupId = groupId;
        dragState.removedIndex = evt.oldIndex;
      },
      onEnd: () => {
        if (dragState.needsRender) {
          scheduleRender();
        }
        resetDragState();
      },
      onAdd: (evt) => {
        if (!dragState.movingItem) {
          const itemId = evt.item.dataset.itemId;
          const located = locateItemById(itemId);
          dragState.movingItem = located ? JSON.parse(JSON.stringify(located.item)) : dragState.activeItem;
        }
        const group = state.items.find((item) => item.id === groupId);
        if (group && dragState.movingItem) {
          const existsIndex = group.apps.findIndex((app) => app.id === dragState.movingItem.id);
          if (existsIndex !== -1) {
            group.apps.splice(existsIndex, 1);
          }
          group.apps.splice(evt.newIndex, 0, dragState.movingItem);
          ensureGroupLabel(group);
          dragState.movingItem = null;
          dragState.stateHandled = true;
          dragState.needsRender = true;
        }
      },
      onRemove: (evt) => {
        const groupIndex = state.items.findIndex((item) => item.id === groupId);
        const group = groupIndex !== -1 ? state.items[groupIndex] : null;
        if (!group) {
          return;
        }
        const removedApp = group.apps.splice(evt.oldIndex, 1)[0];
        dragState.movingItem = removedApp;
        dragState.stateHandled = true;
        dragState.needsRender = true;
        if (group.apps.length <= 1) {
          const remaining = group.apps.slice();
          state.items.splice(groupIndex, 1);
          remaining.forEach((app, offset) => {
            state.items.splice(groupIndex + offset, 0, app);
          });
        }
      },
      onUpdate: (evt) => {
        const group = state.items.find((item) => item.id === groupId);
        if (!group) {
          return;
        }
        const moved = group.apps.splice(evt.oldIndex, 1)[0];
        group.apps.splice(evt.newIndex, 0, moved);
        dragState.needsRender = true;
      },
    });
    state.groupSortables.set(groupId, sortable);
  });
}

async function loadApplications() {
  const apps = await invoke("get_installed_apps");
  state.items = Array.isArray(apps) ? apps.map(createAppItem) : [];
  scheduleRender();
}

window.addEventListener("DOMContentLoaded", () => {
  loadApplications().catch(() => undefined);
});
