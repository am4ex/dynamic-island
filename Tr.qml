pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string lang: {
        const forced = Quickshell.env("ISLAND_LANG");
        if (forced)
            return forced.slice(0, 2).toLowerCase();
        const sources = [Quickshell.env("LANGUAGE"), Quickshell.env("LC_ALL"), Quickshell.env("LC_MESSAGES"), Quickshell.env("LANG")];
        for (let i = 0; i < sources.length; i++) {
            const v = (sources[i] || "").split(":")[0];
            if (v && v !== "C" && v !== "POSIX")
                return v.slice(0, 2).toLowerCase();
        }
        return "en";
    }

    readonly property bool russian: lang === "ru"

    readonly property var en: ({
        "Интернет": "Internet",
        "Игры": "Games",
        "Медиа и графика": "Media & Graphics",
        "Разработка": "Development",
        "Офис": "Office",
        "Система": "System",
        "Утилиты": "Utilities",
        "Поиск": "Search",
        "Частые": "Frequent",
        "Все": "All",
        "Ничего не найдено": "Nothing found",
        "Подключение к ": "Connecting to ",
        "Отключение…": "Disconnecting…",
        "Не получилось подключиться": "Couldn't connect",
        "Enter, чтобы закрыть": "Press Enter to close",
        "ОЗУ": "RAM",
        " ГБ": " GB",
        "Скопировано": "Copied",
        "Пока пусто": "Nothing yet",
        "Поиск сетей…": "Searching…",
        "отключить": "disconnect",
        "Пароль и Enter": "Password, then Enter",
        "Wi-Fi выключен": "Wi-Fi is off",
        "Уведомления": "Notifications",
        "Очистить": "Clear",
        "Новых уведомлений нет": "No new notifications",
        "мин : сек": "min : sec",
        "Старт": "Start",
        " мин": " min",
        "Своё": "Custom",
        "Текст": "Text",
        "Фон": "Background",
        "Изображение или файл": "Image or file",
        "Скопирован в буфер": "Copied to clipboard",
        "Скриншот готов": "Screenshot ready",
        "Привет": "Hello",
        "Время вышло": "Time's up",
        "Таймер · ": "Timer · ",
        "Главная": "Home",
        "Приложения": "Apps",
        "Плеер": "Player",
        "Неизвестный трек": "Unknown track",
        "Неизвестный исполнитель": "Unknown artist",
        "Ищу текст…": "Looking for lyrics…",
        "Текст не найден": "No lyrics found",
        "Вывод": "Output",
        "Ввод": "Input",
        "Устройства": "Devices",
        "Сейчас ничего не играет": "Nothing is playing",
        "Повысить максимальную громкость": "Raise maximum volume"
    })

    function t(s) {
        if (russian)
            return s;
        const v = en[s];
        return v === undefined ? s : v;
    }
}
