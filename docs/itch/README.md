# itch.io 등록 안내

## 업로드 파일 만들기

웹 빌드는 Godot 웹 익스포트를 그대로 압축한 것입니다. 로컬에 Godot 4.7.2와 익스포트 템플릿이 있으면:

```bash
godot --headless --path godot --import                                   # 최초 1회
godot --headless --path godot --export-release "Web" ../build/web/index.html
npm run pack:itch
```

`release/dead-mans-hand-itch-web.zip`이 생깁니다. 압축 루트에 `index.html`·`index.js`·`index.wasm`·`index.pck`가 있습니다. 헤드리스 익스포트는 작업을 마친 뒤 종료에서 멈출 수 있으니, `build/web/index.wasm`이 생겼으면 끝난 것입니다. 중단된 익스포트가 남기는 `index.wasm*.tmp`는 압축에서 뺍니다.

Godot이 없으면 [최신 릴리스](https://github.com/jeiel85/dead-mans-hand-devils-parlor/releases/latest)의 `DeadMansHand-vX.Y.Z-web.zip`을 그대로 올려도 됩니다. 같은 프리셋으로 만든, 루트에 `index.html`이 있는 압축입니다.

## 프로젝트 설정 (Create new project)

| 항목 | 값 |
|---|---|
| Title | Dead Man's Hand: Devil's Parlor |
| Kind of project | **HTML** |
| Uploads | `dead-mans-hand-itch-web.zip` 업로드 후 **This file will be played in the browser** 체크 |
| Embed options → Viewport dimensions | **1280 × 720** (프로젝트 창 크기) |
| Embed options → SharedArrayBuffer support | **끔.** 스레드 없는 웹 익스포트(`variant/thread_support=false`)라 필요 없습니다. 콘솔에 `single-threaded`로 찍힙니다 |
| Embed options → Fullscreen button | 체크 |
| Embed options → Mobile friendly | 체크, **Orientation: Landscape**. 세로로 들면 게임이 "화면을 가로로" 안내를 띄웁니다. 아래 "확인한 것" 참고 |
| Embed options → Automatically start on page load | 끔. 첫 로드가 약 14 MB(gzip)이고, 소리는 클릭 후에야 켜집니다 |
| Classification | Games · Card Game |
| Genre | Card Game, Strategy |
| Tags | `bluffing`, `card-game`, `roguelike`, `russian-roulette`, `singleplayer`, `turn-based`, `godot`, `dark` (덱 빌딩 요소는 없으니 `deck-building`은 넣지 않습니다) |
| Platforms | HTML5, Windows, Linux (아래 내려받기를 함께 올릴 때) |
| Release status | In development (GDD의 일부 기능이 미구현) |
| Pricing | No payments (원하면 Donate) |
| Content disclaimer | 러시안 룰렛(자기 머리에 방아쇠를 당기는) 묘사가 있습니다. itch의 콘텐츠 경고 항목에 적어 두세요 |
| Cover image | [`cover.jpg`](cover.jpg) (630×500, 웹 빌드 실제 화면) |
| Screenshots | [`screenshot-table-en.png`](screenshot-table-en.png)(영어 UI), `docs/shots/`의 타이틀·층 진입·테이블·공개·승리·좁은 화면(한국어 UI) |

## Windows · Linux 내려받기 함께 올리기

같은 itch 페이지에 데스크톱 빌드를 내려받기 파일로 붙일 수 있습니다. 태그 `vX.Y.Z`를 푸시하면 `release.yml`이 만들어 GitHub 릴리스에 붙이는 파일을 그대로 씁니다.

| 파일 | itch 업로드 설정 |
|---|---|
| `DeadMansHand-vX.Y.Z-windows.zip` | 플랫폼 **Windows** 체크. exe 하나(pck 내장) |
| `DeadMansHand-vX.Y.Z-linux.zip` | 플랫폼 **Linux** 체크. 압축을 풀고 `chmod +x DeadMansHand.x86_64` 후 실행 |

- 웹 zip에는 "played in the browser"를, 데스크톱 zip에는 플랫폼만 체크합니다(브라우저 체크는 하나만).
- 코드 서명이 없어서 Windows SmartScreen 경고가 뜰 수 있습니다. 설명에 적어 두면 문의가 줄어듭니다.
- 버전을 올릴 때마다 itch에서도 같은 파일을 교체해야 합니다(butler를 쓰면 채널 `web`·`windows`·`linux`로 나눠 올릴 수 있습니다).

## 게임 동작 메모

- itch.io는 게임을 다른 도메인(itch.zone)의 iframe 안에서 실행합니다. 이 게임은 공유 링크·클립보드·`JavaScriptBridge`·페이지 주소를 쓰지 않으므로 iframe 안에서 달라지는 동작이 없습니다. 전체 화면은 itch의 Fullscreen 버튼이 맡습니다.
- 설정과 기록(최고 층·런 수·승리 수)은 itch.zone 쪽 브라우저 저장소(IndexedDB)에 따로 저장되므로 GitHub Pages 버전과 공유되지 않습니다.
- 브라우저가 iframe 저장소를 막으면 Godot이 메모리 파일 시스템으로 대신 동작합니다. 게임은 그대로 진행되고, 설정과 기록만 새로고침하면 사라집니다.
- 언어는 브라우저 언어가 한국어면 한국어, 그 밖에는 영어로 시작합니다. 상단 바의 `EN`/`한국어` 버튼이나 설정 화면에서 바꿀 수 있습니다.

## 확인한 것 / 못 한 것

- 확인: 로컬에서 만든 zip을 풀어 최상위 페이지와 **다른 출처의 iframe**(localhost → 127.0.0.1) 양쪽에서 띄웠고, 콘솔 오류 없이 타이틀까지 부팅했습니다. IndexedDB를 막은 상태에서도 부팅·설정 변경이 됐습니다. 모바일 뷰포트(390×844, 844×390)에서 터치 이벤트로 버튼과 카드를 눌러 진행되는 것과 세로 화면 안내를 확인했습니다.
- 못 함: 실제 itch.io 페이지 안에서의 실행(업로드 전), 실제 폰에서의 터치(에뮬레이션만), Safari.
- 알려진 제약: 폰 가로(컴팩트 배치)에서 사기 도구 이름이 버튼 폭에서 잘립니다(한국어·영어 모두). 시드 입력칸은 가상 키보드를 띄우지 않아 폰에서는 비워 두면 무작위 시드로 시작합니다.

## 페이지 소개문 (그대로 붙여 넣기)

```
DEAD MAN'S HAND: DEVIL'S PARLOR is a bluffing card game played with a revolver on the table.

You pawned your soul. To win it back, descend seven basement floors of the Devil's saloon and beat the dealer waiting on each one. Every hand is a bluff, every call is a gamble, and whoever gets it wrong puts the gun to their own head.

HOW IT WORKS
• 20-card deck: 6 Kings, 6 Queens, 6 Aces and 2 Jokers. Each round you both draw 5 and a table rank is set.
• Lay 1–3 cards face down and claim they are all the table rank. Jokers count as anything.
• The other side calls the bluff or believes it. Out of cards? You have to call.
• On a call the cards are revealed. If it was a lie, the liar pulls the trigger. If it was true, the caller does.
• The six-chamber revolver's load (live, blank and cursed rounds) is public. The order is not. Exactly one shot per round.
• Drop the dealer to 0 HP to go down a floor.

FEATURES
• A single-player roguelike descent: 7 floors, 7 dealer bosses, each with its own temperament and gimmick
• 4 cheat items — Under-table Mirror, Bottom Deal, Lead Weight, Pact of Greed. Use one per turn; get caught and you fire immediately. Sharper dealers catch more.
• 8 relics and a reward after every floor
• Dealer AI that estimates your lies and learns your bluffing habits
• Seeded runs: share a seed to replay the same deck and cylinder
• Optional 15-second decision timer, sound toggle, color-blind-safe bullet symbols
• English and Korean
• All sound effects are generated in code — no recorded audio

CONTROLS
Click cards to select · Enter lay them down · C call the bluff · P believe it · Esc menu
Works with mouse or touch (phones in landscape).

A full run takes about 20–40 minutes. Content warning: the game depicts russian roulette (characters pull a revolver's trigger on themselves).

Ghost matches and stream-viewer voting are designed in the game design document but not implemented yet.

Windows and Linux builds are below. Source code and the full design document (MIT): https://github.com/jeiel85/dead-mans-hand-devils-parlor
```
