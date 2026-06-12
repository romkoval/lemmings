# Музыка

Музыкальный пак игры — **собственные** чиптюн-композиции в атмосфере
оригинального DOS-саундтрека (не каверы и не аранжировки оригинала: все
мелодии написаны для этого проекта, лицензионно чистые).

- `remake_01.ogg` … `remake_17.ogg` — игровые треки. Уровень берёт трек по
  своему номеру (`AudioManager.play_level_music`), по кругу — как в оригинале;
  кастомные уровни без номера получают стабильный трек по хэшу id.
- `theme.ogg` — тема главного меню (`theme.wav` остался как фолбэк:
  `_resolve()` предпочитает `.ogg`).

Все треки генерируются детерминированно скриптом `scripts/make_music.py`
(numpy + soundfile): pulse/triangle/noise-синтез, секвенсор, эхо. Чтобы
поменять трек — правьте его спеку в `SONGS` и перегенерируйте:

```sh
python3 -m venv /tmp/musicenv && /tmp/musicenv/bin/pip install numpy soundfile
/tmp/musicenv/bin/python scripts/make_music.py assets/music
```

При отсутствии файла `AudioManager.play_music()` тихо пропускает воспроизведение.
