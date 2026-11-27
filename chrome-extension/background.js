
const ICONS = {
    off: {
        16: "pin-gray-16.png",
        32: "pin-gray-32.png"
    },
    on: {
        16: "pin-green-16.png",
        32: "pin-green-32.png"
    }
};

async function paint(tabId, enabled) {
    await chrome.action.setIcon({
        tabId: tabId,
        path: enabled ? ICONS.on : ICONS.off
    });

    await chrome.action.setTitle({
        tabId: tabId,
        title: enabled ? "已置顶：点击取消" : "未置顶：点击开启"
    });
}

chrome.action.onClicked.addListener(async (tab) => {
    const tabId = tab.id;
    const windowId = tab.windowId;

    try {
        const response = await fetch(
            "http://127.0.0.1:8765/toggle",
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({ windowId })
            }
        );

        if (!response.ok) {
            throw new Error("本地辅助程序未正常响应");
        }

        const result = await response.json();

        await paint(tabId, !!result.enabled);

    } catch (e) {
        await chrome.action.setTitle({
            tabId: tabId,
            title: "辅助程序未运行：请先启动 start-helper.bat"
        });

        console.error(e);
    }
});

chrome.windows.onRemoved.addListener(async (windowId) => {
    await chrome.storage.local.remove(`window-${windowId}`);
});
