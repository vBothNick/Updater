local SURUM = "1.6"

script_name("MIMGUI Modern Arayuz Paneli")
script_author("Jakuzi")
script_version(SURUM)

require "lib.moonloader"
local vkeys = require 'vkeys'
local imgui = require 'mimgui'
local ffi = require 'ffi'
local inicfg = require 'inicfg'
local bit = require 'bit'

local sampev_yuklu, sampev = pcall(require, 'samp.events')
local lfs_yuklu, lfs = pcall(require, 'lfs')

local encoding_yuklu, encoding = pcall(require, 'encoding')
local u8, u8_decode
if encoding_yuklu then
    encoding.default = 'CP1254'
    u8 = encoding.UTF8
    u8_decode = function(s) return encoding.UTF8:decode(s) end
else
    u8 = function(s) return s end
    u8_decode = function(s) return s end
end

local guncellemeURL = "https://raw.githubusercontent.com/vBothNick/Updater/main/update.txt"
local duyuruURL = "https://raw.githubusercontent.com/vBothNick/Updater/main/duyuru.txt"
local scriptYolu = thisScript().path

local guncellemeSinyali = false
local guncellemeLinki = ""
local guncellemeSurumu = ""

local aktifBildirim = false
local aktifBildirimMetin = ""
local aktifBildirimZaman = 0.0

function otomatikGuncellemeKontrolu()
    lua_thread.create(function()
        wait(2500)
        local checkFile = getWorkingDirectory() .. "\\update_check.txt"
        local anlikURL = guncellemeURL .. "?t=" .. tostring(os.time())
        downloadUrlToFile(anlikURL, checkFile, function(id, status, p1, p2)
            if status == 58 then 
                local f = io.open(checkFile, "r")
                if f then
                    local sunucuVerisi = f:read("*a")
                    f:close()
                    os.remove(checkFile) 
                    
                    local sunucuSurum, indirmeLinki = sunucuVerisi:match("([%d%.]+)|(.+)")
                    if sunucuSurum and indirmeLinki then
                        local mevcut = tonumber(SURUM:match("[%d%.]+")) or 0
                        local sunucu = tonumber(sunucuSurum) or 0
                        if sunucu > mevcut then
                            guncellemeSurumu = sunucuSurum
                            guncellemeLinki = indirmeLinki
                            guncellemeSinyali = true
                        end
                    end
                end
            end
        end)
    end)
end

function globalDuyuruKontrol()
    lua_thread.create(function()
        while true do
            wait(30000)
            local notifFile = getWorkingDirectory() .. "\\duyuru_check.txt"
            local anlikURL = duyuruURL .. "?t=" .. tostring(os.time())
            downloadUrlToFile(anlikURL, notifFile, function(id, status, p1, p2)
                if status == 58 then
                    local f = io.open(notifFile, "r")
                    if f then
                        local data = f:read("*a")
                        f:close()
                        os.remove(notifFile)
                        local nId, nMsg = data:match("(%d+)|(.+)")
                        if nId and nMsg then
                            nId = tonumber(nId)
                            if nId > (mainIni.ayarlar.last_notif_id or 0) then
                                aktifBildirimMetin = nMsg
                                aktifBildirim = true
                                aktifBildirimZaman = os.clock() + 15.0
                                mainIni.ayarlar.last_notif_id = nId
                                inicfg.save(mainIni, iniFile)
                                addOneOffSound(0,0,0, 1149)
                            end
                        end
                    end
                end
            end)
        end
    end)
end

fontFiles = {
    {"Arial (Kalin)", "arialbd.ttf"}, {"Tahoma (Kalin)", "tahomabd.ttf"}, {"Verdana (Kalin)", "verdanab.ttf"},
    {"Trebuchet MS (Kalin)", "trebucbd.ttf"}, {"Comic Sans MS (Kalin)", "comicbd.ttf"}, {"Courier New (Kalin)", "courbd.ttf"},
    {"Impact", "impact.ttf"}, {"Times New Roman (Kalin)", "timesbd.ttf"}
}

mevcutFontIsimleri = {}
mevcutFontPointers = {}
fontComboCount = 0
fontComboItems = nil
fontNamesPointers = {} 

glyph_ranges = imgui.new.ImWchar[9](0x0020, 0x00FF, 0x0100, 0x017F, 0x0400, 0x04FF, 0x2500, 0x26FF, 0)
bgTexture = nil
btnTexture = nil

local isMenuOpen = false
local animState = 0 
local animProgress = 0.0
local bootState = 0 
local bootStartTime = 0

-- Yeni Animasyon Durum Yöneticileri
local btnAnimStates = {}
local navAnimStates = {}

imgui.OnInitialize(function()
    local config = imgui.ImFontConfig()
    for i, data in ipairs(fontFiles) do
        local path = os.getenv("WINDIR") .. "\\Fonts\\" .. data[2]
        local f = io.open(path, "r")
        if f then
            f:close()
            local ptr = imgui.GetIO().Fonts:AddFontFromFileTTF(path, 19.0, config, glyph_ranges)
            table.insert(mevcutFontIsimleri, data[1])
            table.insert(mevcutFontPointers, ptr)
        end
    end
    
    fontComboCount = #mevcutFontIsimleri
    if fontComboCount > 0 then
        fontComboItems = ffi.new('const char*[?]', fontComboCount)
        for i, isim in ipairs(mevcutFontIsimleri) do
            fontNamesPointers[i] = imgui.new.char[256](isim)
            fontComboItems[i - 1] = fontNamesPointers[i]
        end
    end
    
    local bgPath = getWorkingDirectory() .. "\\arkaplan.jpg"
    local bgFile = io.open(bgPath, "rb")
    if bgFile then
        bgFile:close()
        bgTexture = imgui.CreateTextureFromFile(bgPath)
    end
    
    -- Buton Arka Plan Kontrolu
    local btnBgPath = getWorkingDirectory() .. "\\buton_bg.jpg"
    local btnBgFile = io.open(btnBgPath, "rb")
    if btnBgFile then
        btnBgFile:close()
        btnTexture = imgui.CreateTextureFromFile(btnBgPath)
    end
end)

iniFile = "SAMP_OzelPanel.ini"
animDosya = getWorkingDirectory() .. "\\ModernHUB_Animasyonlar.txt"

mainIni = inicfg.load({
    isimler = {}, komutlar = {}, kisayollar = {}, rp_isimler = {}, rp_komutlar = {}, radar = {}, oto_mesajlar = {}, piyasa = {},
    ayarlar = { 
        kisayol_v2 = 113, mouse_kisayol_v2 = 4, secili_font = 0, chatlog_count = 1,
        tema_r = 0.75, tema_g = 0.55, tema_b = 0.35, yuvarlaklik = 12.0,
        mouse_tip = 1, ses_ve_efekt = true, rgb_border = false, kamera_sabitle = false,
        cruise_kisayol = 67, dinamik_hud = false, hitmarker_aktif = false,
        ozel_scoreboard = false, ozel_nametag = false, sinematik_kisayol = 122,
        dinamik_hud_sabit = false, scoreboard_kisayol = 121, last_notif_id = 0
    },
    afk = { aktif = false, tetikleyici = "Kullanici", mesaj = "Su an klavye basinda degilim, daha sonra donus yapacagim." },
    rol_filtre = { aksan_aktif = false, aksan_metin = "[Ispanyolca] ", telsiz_aktif = false },
    oto_arac = { kemer = false, motor = false },
    oto_login = { aktif = false, sifre = "" }
}, iniFile)

function getKeyName(id)
    if id == 0 or id == nil then return "Atanmadi" end
    for k, v in pairs(vkeys) do
        if v == id and type(k) == "string" and k:sub(1,3) == "VK_" then return k:sub(4) end
    end
    return tostring(id)
end

function getComboName(tusTablosu)
    if not tusTablosu or #tusTablosu == 0 then return "Tus Ata" end
    local names = {}
    for _, k in ipairs(tusTablosu) do
        local name = getKeyName(k)
        if k == vkeys.VK_CONTROL or k == vkeys.VK_LCONTROL or k == vkeys.VK_RCONTROL then name = "CTRL" end
        if k == vkeys.VK_MENU or k == vkeys.VK_LMENU or k == vkeys.VK_RMENU then name = "ALT" end
        if k == vkeys.VK_SHIFT or k == vkeys.VK_LSHIFT or k == vkeys.VK_RSHIFT then name = "SHIFT" end
        table.insert(names, name)
    end
    return table.concat(names, " + ")
end

function formatNumber(n)
    local left,num,right = string.match(tostring(n),'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

seciliCruiseKisayol = imgui.new.int(mainIni.ayarlar.cruise_kisayol or vkeys.VK_C)
bekleCruiseTusu = false
isCruiseActive = false
cruiseSpeed = 0.0

piyasaFiltreleri = {}
piyasaLoglari = {}
inputPiyasa = imgui.new.char[128]("")
marketNotifDurum = false
marketNotifMetin = ""
marketNotifSure = 0.0

meslekAktif = false
meslekBaslangic = 0
meslekBaslangicPara = 0
meslekKazanilan = 0
meslekTur = 0
meslekSonPara = 0
meslekHedefPara = imgui.new.int(50000)

dinamikHudAktif = imgui.new.bool(mainIni.ayarlar.dinamik_hud or false)
dinamikHudSabit = imgui.new.bool(mainIni.ayarlar.dinamik_hud_sabit or false)

hitmarkerAktif = imgui.new.bool(mainIni.ayarlar.hitmarker_aktif or false)
hitmarkerTime = 0.0

ozelScoreboardAktif = imgui.new.bool(mainIni.ayarlar.ozel_scoreboard or false)
seciliScoreboardKisayol = imgui.new.int(mainIni.ayarlar.scoreboard_kisayol or vkeys.VK_F10)
bekleScoreboardTusu = false
scoreboardAcik = false
aramaScoreboard = imgui.new.char[128]("")

ozelNametagAktif = imgui.new.bool(mainIni.ayarlar.ozel_nametag or false)
seciliSinematikKisayol = imgui.new.int(mainIni.ayarlar.sinematik_kisayol or vkeys.VK_F11)
sinematikAktif = false
origSensX, origSensY = 0.0025, 0.0025
bekleSinematikTusu = false

otoLoginAktif = imgui.new.bool(mainIni.oto_login.aktif or false)
otoLoginSifre = imgui.new.char[128](mainIni.oto_login.sifre or "")

local ssListesi = {}
local ssComboItems = ffi.new('const char*[1]')
local ssPointers = {}
local seciliSSIndex = imgui.new.int(-1)
local yuklenenSSTexture = nil
local yuklenenSSIsim = ""
local aramaGaleri = imgui.new.char[128]("")

patched_time = nil
g_SabitZaman = nil

function patch_samp_time_set(enable)
    if enable and patched_time == nil then
        patched_time = readMemory(sampGetBase() + 0x9C0A0, 4, true)
        writeMemory(sampGetBase() + 0x9C0A0, 4, 0x000008C2, true)
    elseif enable == false and patched_time ~= nil then
        writeMemory(sampGetBase() + 0x9C0A0, 4, patched_time, true)
        patched_time = nil
    end
end

function getRiskTekZar(score)
    if score >= 21 then return 100.0 end
    local safe_rolls = 21 - score
    if safe_rolls >= 6 then return 0.0 end
    local bust_rolls = 6 - safe_rolls
    return (bust_rolls / 6.0) * 100.0
end

function getRiskCiftZar(score)
    if score >= 21 then return 100.0 end
    local safe_rolls = 21 - score
    if safe_rolls >= 12 then return 0.0 end
    local combinations = { [2]=1, [3]=2, [4]=3, [5]=4, [6]=5, [7]=6, [8]=5, [9]=4, [10]=3, [11]=2, [12]=1 }
    local bust_count = 0
    for i = 2, 12 do
        if (score + i) > 21 then bust_count = bust_count + combinations[i] end
    end
    return (bust_count / 36.0) * 100.0
end

addEventHandler("onWindowMessage", function(msg, wparam, lparam)
    if msg == 0x0100 or msg == 0x0101 then
        if wparam == vkeys.VK_TAB and ozelScoreboardAktif[0] and not renderWindow[0] and not sampIsChatInputActive() and not sampIsDialogActive() then
            return false 
        end
    end
end)

mouseTipleriListesi = {"Varsayilan (SAMP)", "Neon Ok", "Minimal Nokta", "Crosshair"}
mouseTipItems = ffi.new('const char*[?]', #mouseTipleriListesi)
mouseTipPointers = {}
for i, v in ipairs(mouseTipleriListesi) do
    mouseTipPointers[i] = imgui.new.char[256](v)
    mouseTipItems[i - 1] = mouseTipPointers[i]
end

havaDurumuIsimleri = {"Gunesli Acik", "Bulutlu", "Yagmurlu", "Sisli", "Kizil Gokyuzu (Aksam)", "Gece Karanligi", "Kum Firtinasi"}
havaDurumuIDs = {1, 2, 8, 9, 23, 32, 19}
havaDurumuItems = ffi.new('const char*[?]', #havaDurumuIsimleri)
havaDurumuPointers = {}
for i, v in ipairs(havaDurumuIsimleri) do
    havaDurumuPointers[i] = imgui.new.char[256](v)
    havaDurumuItems[i - 1] = havaDurumuPointers[i]
end

function BilgiKutusu(metin)
    imgui.SameLine()
    imgui.TextColored(imgui.ImVec4(0.5, 0.5, 0.5, 1.0), "(?)")
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(imgui.GetFontSize() * 35.0)
        imgui.TextUnformatted(metin)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
end

charStats = {
    isim = "Bilinmiyor", seviye = "0", exp = "0/0", cinsiyet = "Bilinmiyor", dogum = "Bilinmiyor",
    para = "$0", banka = "$0", birlik = "Yok", rutbe = "Yok", telefon = "Bilinmiyor", meslek = "Issiz",
    vip = "Yok", saat = "0", medeni = "Bekar", es = "Yok", payday = "0 dk", maas = "0 dk",
    can = "100.0", zirh = "0.0", market = "0 vP", tc_no = "Bilinmiyor", uyruk = "Bilinmiyor",
    ehliyet = "Bilinmiyor", ucus = "Bilinmiyor", silah = "Bilinmiyor"
}

bjPlayers = {}
bjData = {}

sesStartT = os.time()
sesFootDist = 0.0
sesCarDist = 0.0
sesMsgCount = 0
sesMoneyEarned = 0
sesMoneyLost = 0
sesCarsUsed = 0
sesPlayersSeen = {}
sesAfkTime = 0
sesMaxSpeed = 0.0
sesShotsFired = 0
sesLastPx, sesLastPy, sesLastPz = 0, 0, 0
sesLastVeh = 0
sesLastMoney = 0
sesLastActive = os.clock()

favoritePlayers = {}
favoriteAlerted = {}
yeniKankaIsim = imgui.new.char[128]("")

chatLog = {}
currentNearbyNames = {}
currentNearbyIDs = {}
nearbyComboItems = ffi.new('const char*[1]')
nearbyPointers = { imgui.new.char[256]("Yakinda oyuncu bulunamadi") }
nearbyComboItems[0] = nearbyPointers[1]

lastNearbyUpdate = 0
seciliChatTarget = imgui.new.int(0)
chatMesajInput = imgui.new.char[256]("")
chatLogCount = imgui.new.int(mainIni.ayarlar.chatlog_count or 1)

function match_trim(str, pattern)
    local res = str:match(pattern)
    if res then return res:match("^%s*(.-)%s*$") end
    return nil
end

ozelButonlar, rpButonlar, animButonlar, radarKelimeler, otoMesajlar = {}, {}, {}, {}, {}
aktifAraclar = {}
comboAracCount = 0
comboAracItems = nil
comboAracPointers = {}
seciliAracIndex = imgui.new.int(0)

tusKuyrugu = {}
renderWindow = imgui.new.bool(false)
mouseAktif = true

inputIsim, inputKomut = imgui.new.char[256](""), imgui.new.char[256]("")
inputRpIsim, inputRpKomut = imgui.new.char[256](""), imgui.new.char[256]("")
inputAnimIsim, inputAnimKomut = imgui.new.char[256](""), imgui.new.char[256]("")
inputRadar = imgui.new.char[128]("")

otoIsim = imgui.new.char[128]("")
otoKomut = imgui.new.char[256]("")
otoGun = imgui.new.int(0)
otoSaat = imgui.new.int(0)
otoDakika = imgui.new.int(5)
otoSaniye = imgui.new.int(0)

seciliFontIndex = imgui.new.int(mainIni.ayarlar.secili_font or 0)
seciliKisayol = imgui.new.int(mainIni.ayarlar.kisayol_v2 or vkeys.VK_F2)
seciliMouseKisayol = imgui.new.int(mainIni.ayarlar.mouse_kisayol_v2 or vkeys.VK_MBUTTON)
temaRengi = imgui.new.float[3](mainIni.ayarlar.tema_r or 0.75, mainIni.ayarlar.tema_g or 0.55, mainIni.ayarlar.tema_b or 0.35)
temaYuvarlaklik = imgui.new.float(mainIni.ayarlar.yuvarlaklik or 12.0)
mouseTip = imgui.new.int(mainIni.ayarlar.mouse_tip or 1)
sesVeEfektAktif = imgui.new.bool(mainIni.ayarlar.ses_ve_efekt)
rgbBorder = imgui.new.bool(mainIni.ayarlar.rgb_border or false)
kameraSabitleAktif = imgui.new.bool(mainIni.ayarlar.kamera_sabitle or false)

beklePanelTusu, bekleMouseTusu = false, false
bindGecikmesi = 0

afkAktif = imgui.new.bool(mainIni.afk.aktif or false)
afkTetikleyici = imgui.new.char[128](mainIni.afk.tetikleyici or "Kullanici")
afkMesaj = imgui.new.char[256](mainIni.afk.mesaj or "Su an klavye basinda degilim, daha sonra donus yapacagim.")
aksanAktif = imgui.new.bool(mainIni.rol_filtre.aksan_aktif or false)
aksanMetin = imgui.new.char[128](mainIni.rol_filtre.aksan_metin or "[Ispanyolca] ")
telsizAktif = imgui.new.bool(mainIni.rol_filtre.telsiz_aktif or false)

otoKemerAktif = imgui.new.bool(mainIni.oto_arac.kemer or false)
otoMotorAktif = imgui.new.bool(mainIni.oto_arac.motor or false)

seciliHava = imgui.new.int(0)
seciliSaat = imgui.new.int(12)

calcMiktar1, calcMiktar2 = imgui.new.int(0), imgui.new.int(0)
calcSonuc = 0

ajandaDosya = getWorkingDirectory() .. "\\SAMP_Ajanda.txt"
ajandaBuffer = imgui.new.char[16384]("")

duzenleRpIndex, duzenleOzelIndex, duzenleAnimIndex = 0, 0, 0
seciliSekme = imgui.new.int(1)

local menuKategoriler = {
    {
        isim = "WORKSPACE",
        acik = true,
        ogeler = {
            {id = 1, isim = "Genel Bakis"},
            {id = 2, isim = "Karakter Profili"},
            {id = 3, isim = "Oturum Istatistikleri"},
            {id = 4, isim = "Canli Sohbet"},
        }
    },
    {
        isim = "GAME & ROLEPLAY",
        acik = true,
        ogeler = {
            {id = 6, isim = "Arac Kontrolleri"},
            {id = 7, isim = "RP Asistani"},
            {id = 8, isim = "Animasyonlar"},
            {id = 17, isim = "Meslek Asistani"},
        }
    },
    {
        isim = "TOOLS & UTILITIES",
        acik = true,
        ogeler = {
            {id = 5, isim = "Oto-Mesaj Botu"},
            {id = 9, isim = "Not Defteri"},
            {id = 10, isim = "Hesap Makinesi"},
            {id = 12, isim = "Zar & Blackjack"},
            {id = 16, isim = "Piyasa Takipcisi"},
            {id = 18, isim = "Ekran Goruntuleri"},
        }
    },
    {
        isim = "PERSONALIZE",
        acik = true,
        ogeler = {
            {id = 11, isim = "Atmosfer & Zaman"},
            {id = 13, isim = "Ozel Kisayollar"},
            {id = 14, isim = "Ek Moduller"},
            {id = 15, isim = "Tema ve Gorunum"},
        }
    }
}

-- YENI ANIMASYONLU BUTON SISTEMI (Glow & Hover & Click Scale)
function AnimButton(isim, beklemeBoyutu)
    local p = imgui.GetCursorScreenPos()
    local cleanName = isim:match("^(.-)##") or isim
    local tSize = imgui.CalcTextSize(cleanName)
    local w = beklemeBoyutu.x > 0 and beklemeBoyutu.x or tSize.x + 24
    local h = beklemeBoyutu.y > 0 and beklemeBoyutu.y or 36.0

    if not btnAnimStates[isim] then btnAnimStates[isim] = { hoverAlpha = 0.0, clickScale = 1.0 } end
    local state = btnAnimStates[isim]

    local clicked = imgui.InvisibleButton(isim, imgui.ImVec2(w, h))
    local hovered = imgui.IsItemHovered()
    local active = imgui.IsItemActive()

    local targetHover = hovered and 1.0 or 0.0
    local targetScale = active and 0.93 or 1.0

    state.hoverAlpha = state.hoverAlpha + (targetHover - state.hoverAlpha) * 0.15
    state.clickScale = state.clickScale + (targetScale - state.clickScale) * 0.3

    local cX = p.x + w / 2
    local cY = p.y + h / 2
    local sW = w * state.clickScale
    local sH = h * state.clickScale

    local drawPosMin = imgui.ImVec2(cX - sW/2, cY - sH/2)
    local drawPosMax = imgui.ImVec2(cX + sW/2, cY + sH/2)

    local dl = imgui.GetWindowDrawList()
    local r, g, b = temaRengi[0], temaRengi[1], temaRengi[2]
    
    local baseCol = imgui.GetColorU32Vec4(imgui.ImVec4(0.2, 0.2, 0.2, 1.0))
    local glowCol = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, state.hoverAlpha * 0.8))
    local borderCol = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, 0.4 + (state.hoverAlpha * 0.6)))

    if state.hoverAlpha > 0.01 then
        for i = 1, 3 do
            local gMin = imgui.ImVec2(drawPosMin.x - i, drawPosMin.y - i)
            local gMax = imgui.ImVec2(drawPosMax.x + i, drawPosMax.y + i)
            dl:AddRectFilled(gMin, gMax, imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, state.hoverAlpha * (0.3 / i))), 8.0)
        end
    end

    if btnTexture then
        dl:AddImageRounded(btnTexture, drawPosMin, drawPosMax, imgui.ImVec2(0,0), imgui.ImVec2(1,1), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1, 0.8 + (state.hoverAlpha*0.2))), 6.0)
    else
        dl:AddRectFilled(drawPosMin, drawPosMax, baseCol, 6.0)
    end
    
    dl:AddRectFilled(drawPosMin, drawPosMax, glowCol, 6.0)
    dl:AddRect(drawPosMin, drawPosMax, borderCol, 6.0, 15, 1.5)

    local tPos = imgui.ImVec2(cX - tSize.x/2, cY - tSize.y/2)
    dl:AddText(tPos, imgui.GetColorU32Vec4(imgui.ImVec4(1, 1, 1, 1)), cleanName)

    if clicked and sesVeEfektAktif[0] then addOneOffSound(0, 0, 0, 1083) end
    return clicked
end

-- YENI ANIMASYONLU NAVIGASYON BUTONU
function ModernNavButton(id, prefix, isim, isSelected, btnBoyut)
    local p = imgui.GetCursorScreenPos()
    local w = btnBoyut.x > 0 and btnBoyut.x or imgui.GetWindowContentRegionWidth()
    local h = btnBoyut.y > 0 and btnBoyut.y or 36.0 
    
    if not navAnimStates[id] then navAnimStates[id] = { hoverAlpha = 0.0, selectLerp = isSelected and 1.0 or 0.0 } end
    local state = navAnimStates[id]

    local clicked = imgui.InvisibleButton("btn_nav_"..id, imgui.ImVec2(w, h))
    local hovered = imgui.IsItemHovered()

    local targetHover = hovered and 1.0 or 0.0
    local targetSelect = isSelected and 1.0 or 0.0

    state.hoverAlpha = state.hoverAlpha + (targetHover - state.hoverAlpha) * 0.15
    state.selectLerp = state.selectLerp + (targetSelect - state.selectLerp) * 0.15

    local dl = imgui.GetWindowDrawList()
    local r, g, b = temaRengi[0], temaRengi[1], temaRengi[2]

    local bgBase = imgui.GetColorU32Vec4(imgui.ImVec4(0.12, 0.12, 0.12, 0.5))
    local bgHover = imgui.GetColorU32Vec4(imgui.ImVec4(0.20, 0.20, 0.20, state.hoverAlpha * 0.8))
    local bgSelect = imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, state.selectLerp * 0.3))

    dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), bgBase, 6.0)
    if state.hoverAlpha > 0.01 then dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), bgHover, 6.0) end
    if state.selectLerp > 0.01 then dl:AddRectFilled(p, imgui.ImVec2(p.x + w, p.y + h), bgSelect, 6.0) end

    if state.selectLerp > 0.01 then
        dl:AddRectFilled(p, imgui.ImVec2(p.x + 4, p.y + h), imgui.GetColorU32Vec4(imgui.ImVec4(r, g, b, state.selectLerp)), 6.0)
    end

    local textCol = imgui.GetColorU32Vec4(imgui.ImVec4(
        0.75 + (0.25 * state.selectLerp),
        0.75 + (0.25 * state.selectLerp),
        0.75 + (0.25 * state.selectLerp),
        1.0
    ))

    local fullText = string.format("%s  %s", prefix, isim)
    local shiftX = (state.hoverAlpha * 5) + (state.selectLerp * 5)
    local textPos = imgui.ImVec2(p.x + 12 + shiftX, p.y + (h - imgui.CalcTextSize(fullText).y) / 2)
    dl:AddText(textPos, textCol, fullText)
    
    if clicked and sesVeEfektAktif[0] then addOneOffSound(0, 0, 0, 1083) end
    return clicked
end

function updateAracCombo()
    local list = {}
    if #aktifAraclar == 0 then table.insert(list, "Cevrede arac bulunamadi (Yenile)")
    else for i, v in ipairs(aktifAraclar) do table.insert(list, string.format("%s (ID: %d) - Plaka: %s", v.isim, v.id, v.plaka)) end end
    comboAracCount = #list
    if comboAracCount > 0 then comboAracItems = ffi.new('const char*[?]', comboAracCount)
    else comboAracItems = ffi.new('const char*[1]') end
    comboAracPointers = {} 
    for i, v in ipairs(list) do comboAracPointers[i] = imgui.new.char[256](v); comboAracItems[i - 1] = comboAracPointers[i] end
    seciliAracIndex[0] = 0 
end

function tazeSSListesi()
    ssListesi = {}
    if lfs_yuklu then
        local yol = os.getenv("USERPROFILE") .. "\\Documents\\GTA San Andreas User Files\\SAMP\\screens\\"
        for file in lfs.dir(yol) do
            if file:match("%.png$") or file:match("%.jpg$") then table.insert(ssListesi, file) end
        end
        table.sort(ssListesi, function(a,b) return a>b end)
    end
end

function ajandaYukle()
    local f = io.open(ajandaDosya, "r")
    if f then ffi.copy(ajandaBuffer, f:read("*a")); f:close() end
end

function ajandaKaydet()
    local f = io.open(ajandaDosya, "w")
    if f then f:write(ffi.string(ajandaBuffer)); f:close(); sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Notlar basariyla kaydedildi.", -1) end
end

function animasyonlariYukle()
    local f = io.open(animDosya, "r"); animButonlar = {}
    if f then
        for line in f:lines() do
            local isim, komut = line:match("([^|]+)|([^|]+)")
            if isim and komut then table.insert(animButonlar, {isim = isim, komut = komut}) end
        end
        f:close()
    else
        local newF = io.open(animDosya, "w")
        if newF then newF:write("Otur|/otur 1\nEl Salla|/anim salla\n"); newF:close(); animButonlar = {{isim="Otur", komut="/otur 1"}, {isim="El Salla", komut="/anim salla"}} end
    end
end

function animasyonlariKaydet()
    local f = io.open(animDosya, "w")
    if f then for i, v in ipairs(animButonlar) do f:write(v.isim .. "|" .. v.komut .. "\n") end f:close() end
end

function ayarlariYukle()
    ozelButonlar, rpButonlar, radarKelimeler, otoMesajlar, piyasaFiltreleri = {}, {}, {}, {}, {}
    if mainIni.isimler then 
        for k, v in pairs(mainIni.isimler) do 
            if mainIni.komutlar[k] then 
                local parsedTus = {}
                if mainIni.kisayollar and mainIni.kisayollar[k] then
                    local raw = mainIni.kisayollar[k]
                    if type(raw) == "string" and raw:find(",") then
                        for x in raw:gmatch("%d+") do table.insert(parsedTus, tonumber(x)) end
                    else
                        local tNum = tonumber(raw)
                        if tNum and tNum ~= 0 then table.insert(parsedTus, tNum) end
                    end
                end
                table.insert(ozelButonlar, {isim = v, komut = mainIni.komutlar[k], tus = parsedTus, bekliyor = false}) 
            end 
        end 
    end
    if mainIni.rp_isimler then for k, v in pairs(mainIni.rp_isimler) do if mainIni.rp_komutlar[k] then table.insert(rpButonlar, {isim = v, komut = mainIni.rp_komutlar[k]}) end end end
    if mainIni.radar then for k, v in pairs(mainIni.radar) do table.insert(radarKelimeler, v) end end
    if mainIni.piyasa then for k, v in pairs(mainIni.piyasa) do table.insert(piyasaFiltreleri, v) end end
    if mainIni.oto_mesajlar then
        for k, v in pairs(mainIni.oto_mesajlar) do
            local parts = {}
            for p in string.gmatch(v, "([^|]+)") do table.insert(parts, p) end
            if #parts >= 6 then table.insert(otoMesajlar, {isim = parts[1], komut = parts[2], gun = tonumber(parts[3]), saat = tonumber(parts[4]), dakika = tonumber(parts[5]), saniye = tonumber(parts[6]), aktif = false, sonraki_zaman = 0}) end
        end
    end
    animasyonlariYukle(); updateAracCombo(); ajandaYukle(); tazeSSListesi()
end

function ayarlariKaydet()
    local y = {isimler = {}, komutlar = {}, kisayollar = {}, rp_isimler = {}, rp_komutlar = {}, radar = {}, oto_mesajlar = {}, piyasa = {}, ayarlar = {}, afk = {}, rol_filtre = {}, oto_arac = {}, oto_login = {}}
    for i, val in ipairs(ozelButonlar) do 
        y.isimler[tostring(i)] = val.isim
        y.komutlar[tostring(i)] = val.komut
        if type(val.tus) == "table" and #val.tus > 0 then
            y.kisayollar[tostring(i)] = table.concat(val.tus, ",")
        else
            y.kisayollar[tostring(i)] = "0"
        end
    end
    for i, val in ipairs(rpButonlar) do y.rp_isimler[tostring(i)] = val.isim; y.rp_komutlar[tostring(i)] = val.komut end
    for i, val in ipairs(radarKelimeler) do y.radar[tostring(i)] = val end
    for i, val in ipairs(piyasaFiltreleri) do y.piyasa[tostring(i)] = val end
    for i, val in ipairs(otoMesajlar) do y.oto_mesajlar[tostring(i)] = string.format("%s|%s|%d|%d|%d|%d", val.isim, val.komut, val.gun, val.saat, val.dakika, val.saniye) end
    
    y.ayarlar.kisayol_v2 = seciliKisayol[0]; y.ayarlar.mouse_kisayol_v2 = seciliMouseKisayol[0]; y.ayarlar.secili_font = seciliFontIndex[0]
    y.ayarlar.tema_r = temaRengi[0]; y.ayarlar.tema_g = temaRengi[1]; y.ayarlar.tema_b = temaRengi[2]
    y.ayarlar.yuvarlaklik = temaYuvarlaklik[0]; y.ayarlar.mouse_tip = mouseTip[0]; y.ayarlar.ses_ve_efekt = sesVeEfektAktif[0]
    y.ayarlar.rgb_border = rgbBorder[0]; y.ayarlar.kamera_sabitle = kameraSabitleAktif[0]
    y.ayarlar.chatlog_count = chatLogCount[0]; y.ayarlar.cruise_kisayol = seciliCruiseKisayol[0]
    y.ayarlar.dinamik_hud = dinamikHudAktif[0]; y.ayarlar.hitmarker_aktif = hitmarkerAktif[0]
    y.ayarlar.dinamik_hud_sabit = dinamikHudSabit[0];
    y.ayarlar.ozel_scoreboard = ozelScoreboardAktif[0]; y.ayarlar.ozel_nametag = ozelNametagAktif[0]
    y.ayarlar.sinematik_kisayol = seciliSinematikKisayol[0]; y.ayarlar.scoreboard_kisayol = seciliScoreboardKisayol[0]
    y.ayarlar.last_notif_id = mainIni.ayarlar.last_notif_id or 0
    
    y.afk.aktif = afkAktif[0]; y.afk.tetikleyici = ffi.string(afkTetikleyici); y.afk.mesaj = ffi.string(afkMesaj)
    y.rol_filtre.aksan_aktif = aksanAktif[0]; y.rol_filtre.aksan_metin = ffi.string(aksanMetin); y.rol_filtre.telsiz_aktif = telsizAktif[0]
    y.oto_arac.kemer = otoKemerAktif[0]; y.oto_arac.motor = otoMotorAktif[0]
    
    y.oto_login.aktif = otoLoginAktif[0]; y.oto_login.sifre = ffi.string(otoLoginSifre)
    
    inicfg.save(y, iniFile); mainIni = inicfg.load(nil, iniFile); animasyonlariKaydet()
end

if sampev_yuklu then
    function sampev.onSendChat(message)
        sesLastActive = os.clock(); sesMsgCount = sesMsgCount + 1
        local yollanacak = message
        if telsizAktif[0] and yollanacak:sub(1,1) ~= "/" then yollanacak = "/t " .. yollanacak end
        if aksanAktif[0] then
            local prefix = u8_decode(ffi.string(aksanMetin))
            if prefix ~= "" and yollanacak:sub(1,3) ~= "/b " and yollanacak:sub(1,4) ~= "/pm " then
                if yollanacak:sub(1,3) == "/t " then yollanacak = "/t " .. prefix .. yollanacak:sub(4)
                elseif yollanacak:sub(1,3) == "/r " then yollanacak = "/r " .. prefix .. yollanacak:sub(4)
                elseif yollanacak:sub(1,3) == "/f " then yollanacak = "/f " .. prefix .. yollanacak:sub(4)
                elseif yollanacak:sub(1,1) ~= "/" then yollanacak = prefix .. yollanacak end
            end
        end
        if yollanacak ~= message then return { yollanacak } end
    end

    function sampev.onSendWeaponsUpdate()
        if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
            local res, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
            if res and isCharShooting(PLAYER_PED) then sesShotsFired = sesShotsFired + 1 end
        end
    end
    
    function sampev.onSendGiveDamage(playerId, damage, weapon, bodypart)
        if hitmarkerAktif[0] then
            hitmarkerTime = os.clock() + 0.3
            addOneOffSound(0, 0, 0, 1131) 
        end
    end

    function sampev.onSendCommand(cmd)
        sesLastActive = os.clock()
        if cmd == "/arac liste" then aktifAraclar = {}; updateAracCombo() end
        local colorMatch, msgMatch = cmd:match("^/fchat (%x%x%x%x%x%x) (.+)")
        if colorMatch and msgMatch then
            sampAddChatMessage(msgMatch, tonumber("0xFF"..colorMatch, 16))
            return false
        end
    end
    
    function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
        if otoLoginAktif[0] then
            local t = title:lower()
            if style == 1 or style == 3 then
                if t:find("giriş") or t:find("login") or t:find("şifre") or t:find("sifre") or t:find("hesap") then
                    local pass = ffi.string(otoLoginSifre)
                    if pass ~= "" then
                        sampSendDialogResponse(dialogId, 1, 0, pass)
                        return false
                    end
                end
            end
        end
    end
    
    function sampev.onServerMessage(color, text)
        local temizMetin = text:gsub("{%x%x%x%x%x%x}", "")
        local lower_text = temizMetin:lower()
        
        for _, kelime in ipairs(piyasaFiltreleri) do
            if kelime ~= "" and lower_text:find(kelime:lower()) then
                table.insert(piyasaLoglari, 1, {zaman = os.date("%H:%M:%S"), metin = temizMetin, kelime = kelime})
                if #piyasaLoglari > 100 then table.remove(piyasaLoglari) end
                marketNotifMetin = temizMetin
                marketNotifSure = os.clock() + 5.0
                marketNotifDurum = true
                addOneOffSound(0,0,0, 1085)
                break
            end
        end
        
        local noTimeText = temizMetin:gsub("^%[%d%d:%d%d:%d%d%]%s*", "")
        local lowerNoTime = noTimeText:lower()
        local isWhisper = lowerNoTime:find("f.s.lda") or lowerNoTime:find("f.s.lt")
        
        local isMeDo = temizMetin:match("^%* ")
        local isPlayerChat = temizMetin:match("^[A-Z]%a+_[A-Z]%a+:") or temizMetin:match("^[A-Z]%a+ [A-Z]%a+:") or temizMetin:match("^[A-Z]%w+:")
        local isPM = temizMetin:find("%(%( << ") or temizMetin:find("%(%( >> ") or temizMetin:find("%[PM%]") or temizMetin:find("PM %-")
        if isMeDo or isPlayerChat or isPM or isWhisper then
            table.insert(chatLog, { txt = u8(temizMetin), raw = text:gsub("{%x%x%x%x%x%x}", "") })
            if #chatLog > 200 then table.remove(chatLog, 1) end 
        end
        
        if temizMetin:find("Aktif %- ") then
            local model, id, plaka = temizMetin:match("Aktif %- (.-)%s*%((%d+)%) %- Plaka: (.-) %-")
            if model and id and plaka then table.insert(aktifAraclar, {isim = model, id = tonumber(id), plaka = plaka}); updateAracCombo() end
        end
        
        local z1, z2, pName = temizMetin:match("%* Cift zar atti ve (%d+),%s*(%d+) geldi%. %(%(%s*(.-)%s*%)%)")
        if z1 and z2 and pName then
            if not bjData[pName] then table.insert(bjPlayers, pName); bjData[pName] = { toplam = 0, tekli = 0, ciftli = 0 } end
            bjData[pName].toplam = bjData[pName].toplam + tonumber(z1) + tonumber(z2)
            bjData[pName].tekli = bjData[pName].tekli + 2
            bjData[pName].ciftli = bjData[pName].ciftli + 1
        end
        
        local zTek, pNameTek = temizMetin:match("%* Tek zar atti ve (%d+) geldi%. %(%(%s*(.-)%s*%)%)")
        if not zTek then zTek, pNameTek = temizMetin:match("%* Zar atti ve (%d+) geldi%. %(%(%s*(.-)%s*%)%)") end
        if zTek and pNameTek then
            if not bjData[pNameTek] then table.insert(bjPlayers, pNameTek); bjData[pNameTek] = { toplam = 0, tekli = 0, ciftli = 0 } end
            bjData[pNameTek].toplam = bjData[pNameTek].toplam + tonumber(zTek)
            bjData[pNameTek].tekli = bjData[pNameTek].tekli + 1
        end
        
        if temizMetin:find("Karakter:") and temizMetin:find("Seviye:") then
            charStats.isim = match_trim(temizMetin, "Karakter:%s*([^|]+)") or charStats.isim
            charStats.seviye = match_trim(temizMetin, "Seviye:%s*([^|]+)") or charStats.seviye
            charStats.exp = match_trim(temizMetin, "EXP:%s*([^|]+)") or charStats.exp
        elseif temizMetin:find("Cinsiyet:") and temizMetin:find("Do.um Tarihi:") then
            charStats.cinsiyet = match_trim(temizMetin, "Cinsiyet:%s*([^|]+)") or charStats.cinsiyet
            charStats.dogum = match_trim(temizMetin, "Do.um Tarihi:%s*([^|]+)") or charStats.dogum
        elseif temizMetin:find("SQLID:") then
            charStats.para = match_trim(temizMetin, "Para:%s*([^|]+)") or charStats.para
            charStats.saat = match_trim(temizMetin, "Oynama Saati:%s*([^|]+)") or charStats.saat
            charStats.birlik = match_trim(temizMetin, "Birlik:%s*([^|]+)") or charStats.birlik
            charStats.rutbe = match_trim(temizMetin, "R.tbe:%s*(.+)") or charStats.rutbe
        elseif temizMetin:find("Telefon Numaras.:") then
            charStats.telefon = match_trim(temizMetin, "Telefon Numaras.:%s*([^|]+)") or charStats.telefon
            charStats.banka = match_trim(temizMetin, "Banka Hesab.:%s*([^|]+)") or charStats.banka
        elseif temizMetin:find("Ba.ıml.l.k:") or temizMetin:find("Can:") then
            charStats.can = match_trim(temizMetin, "Can:%s*([^|]+)") or charStats.can
            charStats.zirh = match_trim(temizMetin, "Z.rh:%s*([^|]+)") or charStats.zirh
            charStats.meslek = match_trim(temizMetin, "Meslek:%s*(.+)") or charStats.meslek
        elseif temizMetin:find("Market Bakiyesi:") then
            charStats.market = match_trim(temizMetin, "Market Bakiyesi:%s*([^|]+)") or charStats.market
            charStats.vip = match_trim(temizMetin, "VIP Durumu:%s*([^|]+)") or charStats.vip
        elseif temizMetin:find("Payday:") then
            charStats.payday = match_trim(temizMetin, "Payday:%s*([^|]+)") or charStats.payday
            charStats.maas = match_trim(temizMetin, "Maa.:%s*([^|]+)") or charStats.maas
        elseif temizMetin:find("Medeni Durum:") then
            charStats.medeni = match_trim(temizMetin, "Medeni Durum:%s*([^|]+)") or charStats.medeni
            charStats.es = match_trim(temizMetin, "E.i:%s*([^|]+)") or charStats.es
        elseif temizMetin:find("Vatanda.l.k Numaras.:") then
            charStats.tc_no = match_trim(temizMetin, "Vatanda.l.k Numaras.:%s*(.+)") or charStats.tc_no
        elseif temizMetin:find("Uyruk / K.ken:") then
            charStats.uyruk = match_trim(temizMetin, "Uyruk / K.ken:%s*(.+)") or charStats.uyruk
        elseif temizMetin:find("^%s*Ehliyet:") and not temizMetin:find("%[") then
            charStats.ehliyet = match_trim(temizMetin, "Ehliyet:%s*(.+)") or charStats.ehliyet
        elseif temizMetin:find("^%s*U.u. Lisans.:") then
            charStats.ucus = match_trim(temizMetin, "U.u. Lisans.:%s*(.+)") or charStats.ucus
        elseif temizMetin:find("^%s*Silah Ta..ma Lisans.:") then
            charStats.silah = match_trim(temizMetin, "Silah Ta..ma Lisans.:%s*(.+)") or charStats.silah
        end
        
        local kendiMesaji = false
        if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
            local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
            if res then
                local myName = sampGetPlayerNickname(myId)
                if myName then
                    local myNameSpaced = myName:gsub("_", " ")
                    if temizMetin:find("^%* " .. myNameSpaced) or temizMetin:find("^" .. myNameSpaced .. ":") then kendiMesaji = true end
                end
            end
        end
        
        if not kendiMesaji and not temizMetin:find("%[Radar%]") then
            for _, kelime in ipairs(radarKelimeler) do
                if kelime ~= "" and lower_text:find(kelime:lower()) then
                    addOneOffSound(0, 0, 0, 1057)
                    sampAddChatMessage(string.format("{FF0000}[Radar] {FFFFFF}Belirtilen kelime sohbette algilandi ({FFFF00}%s{FFFFFF}): %s", kelime, temizMetin), -1)
                    break 
                end
            end
        end
        
        if afkAktif[0] then
            local tetikKelime = ffi.string(afkTetikleyici)
            if tetikKelime ~= "" and temizMetin:find(tetikKelime) and not temizMetin:find("%[AFK%]") then
                local sender_id = temizMetin:match("%((%d+)%)")
                if sender_id then lua_thread.create(function() wait(1200); sampSendChat(string.format("/pm %s [AFK] %s", sender_id, u8_decode(ffi.string(afkMesaj)))) end) end
            end
        end
    end
end

function ModernTemaUygula()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    style.WindowPadding     = imgui.ImVec2(0, 0)
    style.FramePadding      = imgui.ImVec2(10, 8)
    style.ItemSpacing       = imgui.ImVec2(12, 10)
    style.WindowRounding    = 12.0
    style.ChildRounding     = 8.0
    style.FrameRounding     = 6.0
    style.ScrollbarRounding = 12.0
    style.TabRounding       = 6.0
    style.WindowBorderSize  = 1.5 
    
    style.ChildBorderSize   = 0.0
    colors[clr.ChildBg]     = ImVec4(0.00, 0.00, 0.00, 0.00) 
    style.FrameBorderSize   = 0.0

    -- SAF SIYAH ARKA PLAN MANTIGI
    if bgTexture then
        colors[clr.WindowBg] = ImVec4(0.05, 0.05, 0.05, 0.85) 
    else
        colors[clr.WindowBg] = ImVec4(0.03, 0.03, 0.03, 1.00)
    end

    colors[clr.PopupBg]              = ImVec4(0.15, 0.15, 0.15, 0.98)

    local tR, tG, tB = temaRengi[0], temaRengi[1], temaRengi[2]
    local accentColor = ImVec4(tR, tG, tB, 0.85)
    local accentHover = ImVec4(tR, tG, tB, 0.95)
    local accentActive = ImVec4(tR, tG, tB, 1.00)

    colors[clr.Border]               = ImVec4(tR, tG, tB, 0.65)
    colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)

    colors[clr.FrameBg]              = ImVec4(0.12, 0.12, 0.12, 0.80)
    colors[clr.FrameBgHovered]       = ImVec4(0.25, 0.25, 0.25, 0.90)
    colors[clr.FrameBgActive]        = ImVec4(0.30, 0.30, 0.30, 1.00)

    colors[clr.CheckMark]            = accentHover
    colors[clr.SliderGrab]           = accentColor
    colors[clr.SliderGrabActive]     = accentActive

    colors[clr.Button]               = ImVec4(0.20, 0.20, 0.20, 0.85)
    colors[clr.ButtonHovered]        = ImVec4(tR, tG, tB, 0.75)
    colors[clr.ButtonActive]         = ImVec4(tR, tG, tB, 1.00)

    colors[clr.Header]               = ImVec4(0.30, 0.30, 0.30, 0.85)
    colors[clr.HeaderHovered]        = ImVec4(tR, tG, tB, 0.75)
    colors[clr.HeaderActive]         = ImVec4(tR, tG, tB, 1.00)
    
    colors[clr.Separator]            = ImVec4(1.00, 1.00, 1.00, 0.10)
    colors[clr.SeparatorHovered]     = ImVec4(1.00, 1.00, 1.00, 0.15)
    colors[clr.SeparatorActive]      = ImVec4(1.00, 1.00, 1.00, 0.20)

    colors[clr.PlotHistogram]        = accentColor
    colors[clr.PlotHistogramHovered] = accentActive

    colors[clr.Text]                 = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled]         = ImVec4(0.70, 0.70, 0.70, 1.00)
end

local function DrawStat(label, val, offset, colorObj)
    local off = offset or 160
    imgui.TextColored(imgui.ImVec4(0.80, 0.80, 0.80, 1.0), label .. ":")
    imgui.SameLine(off) 
    local c = colorObj or imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
    if not colorObj then
        if val == "Yok" or val == "Issiz" then c = imgui.ImVec4(0.85, 0.35, 0.35, 1.0) 
        elseif val == "Mevcut" then c = imgui.ImVec4(0.35, 0.85, 0.45, 1.0) end
    end
    imgui.TextColored(c, tostring(val))
end

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] or marketNotifDurum or (dinamikHudAktif[0] and not sinematikAktif) or hitmarkerAktif[0] or (ozelScoreboardAktif[0] and scoreboardAcik and not sinematikAktif) or ozelNametagAktif[0] or sinematikAktif or aktifBildirim end,
    function(player)
        local sw, sh = getScreenResolution()
        
        ModernTemaUygula()
        local fontAktifState = false
        if fontComboCount > 0 and mevcutFontPointers[seciliFontIndex[0] + 1] then
            imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1])
            fontAktifState = true
        end
        
        if aktifBildirim then
            local pKalan = (aktifBildirimZaman - os.clock()) / 15.0
            if pKalan > 0 then
                imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh - 100), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
                imgui.SetNextWindowSize(imgui.ImVec2(600, 90), imgui.Cond.Always)
                imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.18, 0.18, 0.18, 0.98))
                imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
                imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.5)
                imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 0.8))
                
                imgui.Begin("GlobalDuyuruUI", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoSavedSettings)
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.00), "GLOBAL SISTEM DUYURUSU")
                imgui.Dummy(imgui.ImVec2(0, 2))
                imgui.TextWrapped(aktifBildirimMetin)
                
                local dl = imgui.GetWindowDrawList()
                local p = imgui.GetCursorScreenPos()
                local w = imgui.GetWindowContentRegionWidth()
                dl:AddRectFilled(imgui.ImVec2(p.x, p.y + 10), imgui.ImVec2(p.x + w, p.y + 15), imgui.GetColorU32Vec4(imgui.ImVec4(0.15, 0.15, 0.15, 0.6)), 3.0)
                dl:AddRectFilled(imgui.ImVec2(p.x, p.y + 10), imgui.ImVec2(p.x + (w * pKalan), p.y + 15), imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0)), 3.0)
                
                imgui.End()
                imgui.PopStyleVar(2)
                imgui.PopStyleColor(2)
            else
                aktifBildirim = false
            end
        end

        if sinematikAktif then
            local fg = imgui.GetForegroundDrawList()
            fg:AddRectFilled(imgui.ImVec2(0, 0), imgui.ImVec2(sw, sh * 0.12), imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,1)))
            fg:AddRectFilled(imgui.ImVec2(0, sh * 0.88), imgui.ImVec2(sw, sh), imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,1)))
        end

        local resSpwn, mySpwnId = false, 0
        if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
            resSpwn, mySpwnId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        end

        if ozelNametagAktif[0] and not sinematikAktif and resSpwn then
            local cX, cY, cZ = getCharCoordinates(PLAYER_PED)
            for _, ped in ipairs(getAllChars()) do
                if ped ~= PLAYER_PED then
                    local isP, pId = sampGetPlayerIdByCharHandle(ped)
                    if isP then
                        local resX, resY, resZ = getCharCoordinates(ped)
                        local dist = getDistanceBetweenCoords3d(cX, cY, cZ, resX, resY, resZ)
                        if dist < 35.0 and isLineOfSightClear(cX, cY, cZ, resX, resY, resZ, true, false, false, true, false) then
                            if isPointOnScreen(resX, resY, resZ, 1.0) then
                                local res2, sx, sy = convert3DCoordsToScreen(resX, resY, resZ + 1.0)
                                if res2 and sx and sy then
                                    local nName = sampGetPlayerNickname(pId):gsub("_", " ")
                                    local hp = sampGetPlayerHealth(pId)
                                    local armor = sampGetPlayerArmor(pId)
                                    local tSize = imgui.CalcTextSize(nName .. " (" .. pId .. ")")
                                    local fg = imgui.GetBackgroundDrawList()
                                    
                                    fg:AddText(imgui.ImVec2(sx - (tSize.x/2), sy), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,1)), nName .. " (" .. pId .. ")")
                                    
                                    fg:AddRectFilled(imgui.ImVec2(sx - 25, sy + tSize.y + 2), imgui.ImVec2(sx + 25, sy + tSize.y + 6), imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,0.7)))
                                    fg:AddRectFilled(imgui.ImVec2(sx - 25, sy + tSize.y + 2), imgui.ImVec2(sx - 25 + (50 * (math.min(hp, 100) / 100)), sy + tSize.y + 6), imgui.GetColorU32Vec4(imgui.ImVec4(0.3,0.9,0.3,1)))
                                    
                                    if armor > 0 then
                                        fg:AddRectFilled(imgui.ImVec2(sx - 25, sy + tSize.y + 8), imgui.ImVec2(sx + 25, sy + tSize.y + 12), imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,0.7)))
                                        fg:AddRectFilled(imgui.ImVec2(sx - 25, sy + tSize.y + 8), imgui.ImVec2(sx - 25 + (50 * (math.min(armor, 100) / 100)), sy + tSize.y + 12), imgui.GetColorU32Vec4(imgui.ImVec4(0.8,0.8,0.8,1)))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if not sinematikAktif and resSpwn then
            local cX, cY, cZ = getCharCoordinates(PLAYER_PED)
            for _, ped in ipairs(getAllChars()) do
                if ped ~= PLAYER_PED then
                    local isP, pId = sampGetPlayerIdByCharHandle(ped)
                    if isP then
                        local nName = sampGetPlayerNickname(pId)
                        if nName then
                            nName = nName:gsub("_", " ")
                            if favoritePlayers[nName] then
                                local resX, resY, resZ = getCharCoordinates(ped)
                                local dist = getDistanceBetweenCoords3d(cX, cY, cZ, resX, resY, resZ)
                                if dist < 50.0 and isLineOfSightClear(cX, cY, cZ, resX, resY, resZ, true, false, false, true, false) then
                                    if isPointOnScreen(resX, resY, resZ, 1.0) then
                                        local yOffset = ozelNametagAktif[0] and 1.3 or 1.1 
                                        local res2, sx, sy = convert3DCoordsToScreen(resX, resY, resZ + yOffset)
                                        if res2 and sx and sy then
                                            local foreDL = imgui.GetBackgroundDrawList()
                                            local tSize = imgui.CalcTextSize("TAKIM")
                                            foreDL:AddRectFilled(imgui.ImVec2(sx - (tSize.x/2) - 5, sy - 5), imgui.ImVec2(sx + (tSize.x/2) + 5, sy + tSize.y + 5), imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,0.6)), 5.0)
                                            foreDL:AddText(imgui.ImVec2(sx - (tSize.x/2), sy), imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0)), "TAKIM")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if hitmarkerAktif[0] and os.clock() < hitmarkerTime and not sinematikAktif then
            local cx, cy = sw / 2, sh / 2
            local alpha = (hitmarkerTime - os.clock()) / 0.3
            local c = imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 1.0, alpha))
            local dl = imgui.GetForegroundDrawList()
            local size = 10
            local th = 2.0
            dl:AddLine(imgui.ImVec2(cx - size, cy - size), imgui.ImVec2(cx + size, cy + size), c, th)
            dl:AddLine(imgui.ImVec2(cx - size, cy + size), imgui.ImVec2(cx + size, cy - size), c, th)
        end

        if dinamikHudAktif[0] and not sinematikAktif and resSpwn then
            imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(15.0, 15.0))
            imgui.SetNextWindowBgAlpha(0.4)
            local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize
            if dinamikHudSabit[0] then flags = flags + imgui.WindowFlags.NoMove end
            
            if imgui.Begin("Dinamik HUD", nil, flags) then
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Dinamik HUD")
                imgui.Separator()
                imgui.Text(string.format("FPS: %d", math.floor(imgui.GetIO().Framerate)))
                imgui.Text(string.format("Ping: %d", sampGetPlayerPing(mySpwnId)))
                imgui.Text(string.format("Saat: %s", os.date("%H:%M:%S")))
            end
            imgui.End()
            imgui.PopStyleVar()
        end

        if ozelScoreboardAktif[0] and scoreboardAcik and not sinematikAktif then
            imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(600, 500), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.18, 0.18, 0.18, 0.98))
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
            
            imgui.Begin("##CustomScoreboard", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Sunucu Oyuncu Listesi")
            imgui.SameLine(400)
            imgui.PushItemWidth(180)
            imgui.InputText("Ara", aramaScoreboard, 128)
            imgui.PopItemWidth()
            imgui.Separator()
            
            imgui.BeginChild("scList", imgui.ImVec2(0, 0), false)
            imgui.Columns(3, "sbCols")
            imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.0), "ID")
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.0), "Oyuncu Ismi")
            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.0), "Ping")
            imgui.NextColumn()
            imgui.Separator()
            
            local fStr = ffi.string(aramaScoreboard):lower()
            for i = 0, 1000 do
                if sampIsPlayerConnected(i) then
                    local name = sampGetPlayerNickname(i)
                    if fStr == "" or name:lower():find(fStr) or tostring(i) == fStr then
                        local ping = sampGetPlayerPing(i)
                        imgui.Text(tostring(i))
                        imgui.NextColumn()
                        imgui.Text(name)
                        imgui.NextColumn()
                        imgui.Text(tostring(ping))
                        imgui.NextColumn()
                    end
                end
            end
            
            imgui.Columns(1)
            imgui.EndChild()
            imgui.End()
            imgui.PopStyleColor()
            imgui.PopStyleVar()
        end

        local isAnyMenuOpen = renderWindow[0] or (ozelScoreboardAktif[0] and scoreboardAcik and not sinematikAktif)
        if isAnyMenuOpen then
            player.HideCursor = not mouseAktif
            if ozelScoreboardAktif[0] and scoreboardAcik and not renderWindow[0] then
                player.HideCursor = false
            end
        else
            player.HideCursor = true
        end

        if marketNotifDurum and not sinematikAktif then
            local currentClock = os.clock()
            if currentClock < marketNotifSure then
                local pKalan = (marketNotifSure - currentClock) / 5.0
                local yOffset = aktifBildirim and (sh - 200) or (sh - 100)
                
                imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, yOffset), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
                imgui.SetNextWindowSize(imgui.ImVec2(600, 90), imgui.Cond.Always)
                imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.18, 0.18, 0.18, 0.95))
                imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 12.0)
                imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1.5)
                imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 0.8))
                
                imgui.Begin("MarketNotifUI", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoSavedSettings)
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Piyasa Ilan Radari Tetiklendi!")
                imgui.Dummy(imgui.ImVec2(0, 2))
                imgui.TextWrapped(marketNotifMetin)
                
                local dl = imgui.GetWindowDrawList()
                local p = imgui.GetCursorScreenPos()
                local w = imgui.GetWindowContentRegionWidth()
                dl:AddRectFilled(imgui.ImVec2(p.x, p.y + 10), imgui.ImVec2(p.x + w, p.y + 15), imgui.GetColorU32Vec4(imgui.ImVec4(0.15, 0.15, 0.15, 0.6)), 3.0)
                dl:AddRectFilled(imgui.ImVec2(p.x, p.y + 10), imgui.ImVec2(p.x + (w * pKalan), p.y + 15), imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0)), 3.0)

                imgui.End()
                imgui.PopStyleVar(2)
                imgui.PopStyleColor(2)
            else marketNotifDurum = false end
        end
        
        if not renderWindow[0] then 
            if fontAktifState then imgui.PopFont() end
            return 
        end
        
        local currentTime = os.clock()
        if bootState == 1 or bootState == 2 then
            local gecenSure = currentTime - bootStartTime
            imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
            imgui.SetNextWindowSize(imgui.ImVec2(400, 200), imgui.Cond.Always)
            imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.05, 0.05, 0.05, 0.95))
            imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 15.0)
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 1.0)
            
            imgui.Begin("BootScreen", renderWindow, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove)
            
            if bootState == 1 then
                if gecenSure < 3.0 then
                    local alpha = math.abs(math.sin(gecenSure * 3))
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], alpha))
                    local text = "Sistem Yukleniyor..."
                    local tSize = imgui.CalcTextSize(text)
                    imgui.SetCursorPos(imgui.ImVec2((400 - tSize.x)/2, (200 - tSize.y)/2))
                    imgui.Text(text)
                    imgui.PopStyleColor()
                else bootState = 2; bootStartTime = os.clock() end
            elseif bootState == 2 then
                if gecenSure < 3.0 then
                    local alpha = (gecenSure < 1.5) and (gecenSure / 1.5) or (1.0 - ((gecenSure - 1.5) / 1.5))
                    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 1.0, 1.0, alpha))
                    local text = "\xE2\x99\xA0 KaUI"
                    local tSize = imgui.CalcTextSize(text)
                    imgui.SetCursorPos(imgui.ImVec2((400 - (tSize.x * 1.5))/2, (200 - (tSize.y * 1.5))/2))
                    imgui.SetWindowFontScale(1.5)
                    imgui.Text(text)
                    imgui.SetWindowFontScale(1.0)
                    imgui.PopStyleColor()
                else bootState = 3; animState = 1 end
            end
            imgui.End()
            imgui.PopStyleVar(2)
            imgui.PopStyleColor()
            
            if fontAktifState then imgui.PopFont() end
            return 
        end

        if animState == 1 then
            animProgress = animProgress + 0.08
            if animProgress >= 1.0 then animProgress = 1.0; animState = 2 end
        elseif animState == 3 then
            animProgress = animProgress - 0.08
            if animProgress <= 0.0 then animProgress = 0.0; animState = 0; renderWindow[0] = false; mouseAktif = false; return end
        end

        local targetAlpha = mouseAktif and 1.0 or 0.5
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, animProgress * targetAlpha)

        if mouseTip[0] ~= 0 then
            local showCursor = (renderWindow[0] and mouseAktif) or (ozelScoreboardAktif[0] and scoreboardAcik and not renderWindow[0])
            if showCursor then
                imgui.GetIO().MouseDrawCursor = true
                imgui.SetMouseCursor(imgui.MouseCursor.None)
                local foreDrawList = imgui.GetForegroundDrawList()
                local mx, my = imgui.GetMousePos().x, imgui.GetMousePos().y
                local alpha = (renderWindow[0] and animProgress) or 1.0
                local c = imgui.GetColorU32Vec4(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], alpha))
                local cOut = imgui.GetColorU32Vec4(imgui.ImVec4(0, 0, 0, alpha))
                
                if mouseTip[0] == 1 then
                    foreDrawList:AddTriangleFilled(imgui.ImVec2(mx, my), imgui.ImVec2(mx+15, my+5), imgui.ImVec2(mx+5, my+15), c)
                    foreDrawList:AddTriangle(imgui.ImVec2(mx, my), imgui.ImVec2(mx+15, my+5), imgui.ImVec2(mx+5, my+15), cOut, 1.5)
                elseif mouseTip[0] == 2 then
                    foreDrawList:AddCircleFilled(imgui.ImVec2(mx, my), 5.0, c)
                    foreDrawList:AddCircle(imgui.ImVec2(mx, my), 6.0, cOut, 0, 1.5)
                elseif mouseTip[0] == 3 then
                    foreDrawList:AddLine(imgui.ImVec2(mx-10, my), imgui.ImVec2(mx+10, my), c, 2.0)
                    foreDrawList:AddLine(imgui.ImVec2(mx, my-10), imgui.ImVec2(mx, my+10), c, 2.0)
                end
            else
                imgui.GetIO().MouseDrawCursor = false
            end
        else
            imgui.GetIO().MouseDrawCursor = false
        end

        imgui.SetNextWindowPos(imgui.ImVec2(sw/2, sh/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(1000, 700), imgui.Cond.FirstUseEver)
        
        local mainWindowFlags = bit.bor(imgui.WindowFlags.NoCollapse, imgui.WindowFlags.NoTitleBar)
        if not mouseAktif then
            local noMouseInputs = imgui.WindowFlags.NoMouseInputs or 512
            mainWindowFlags = bit.bor(mainWindowFlags, imgui.WindowFlags.NoMove, noMouseInputs)
        end

        imgui.Begin("KaUI", renderWindow, mainWindowFlags)
        
        local bgDrawList = imgui.GetWindowDrawList()
        local wPos = imgui.GetWindowPos()
        local wSize = imgui.GetWindowSize()

        if bgTexture then
            bgDrawList:AddImage(bgTexture, wPos, imgui.ImVec2(wPos.x + wSize.x, wPos.y + wSize.y))
            bgDrawList:AddRectFilled(wPos, imgui.ImVec2(wPos.x + wSize.x, wPos.y + wSize.y), imgui.GetColorU32Vec4(imgui.ImVec4(0.05, 0.05, 0.05, 0.4)))
        end
        
        imgui.SetCursorPos(imgui.ImVec2(24, 20))
        imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "\xE2\x99\xA0 KaUI")
        imgui.SetCursorPos(imgui.ImVec2(24, 45))
        imgui.TextColored(imgui.ImVec4(0.80, 0.80, 0.80, 1.0), "SAMP MULTIPURPOSE CONFIGURATOR")
        
        imgui.SetCursorPos(imgui.ImVec2(wSize.x - 38, 18))
        if imgui.InvisibleButton("KapatX", imgui.ImVec2(22, 22)) then animState = 3 end
        local isHoverX = imgui.IsItemHovered()
        local bgX = isHoverX and imgui.GetColorU32Vec4(imgui.ImVec4(0.8, 0.3, 0.3, 1.0)) or imgui.GetColorU32Vec4(imgui.ImVec4(0.2, 0.2, 0.2, 1.0))
        bgDrawList:AddRectFilled(imgui.ImVec2(wPos.x + wSize.x - 38, wPos.y + 18), imgui.ImVec2(wPos.x + wSize.x - 16, wPos.y + 40), bgX, 4.0)
        bgDrawList:AddText(imgui.ImVec2(wPos.x + wSize.x - 31, wPos.y + 20), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,1)), "X")

        imgui.SetCursorPos(imgui.ImVec2(0, 85))
        
        imgui.BeginChild("Sidebar", imgui.ImVec2(280, -40), false) 
        for kIdx, kategori in ipairs(menuKategoriler) do
            imgui.SetCursorPosX(20)
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), kategori.isim)
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            for i, oge in ipairs(kategori.ogeler) do
                imgui.SetCursorPosX(20)
                local iconFormat = ""
                
                if i == 1 and #kategori.ogeler > 1 then
                    iconFormat = "\xE2\x95\x94"
                elseif i == #kategori.ogeler then
                    iconFormat = "\xE2\x95\x9A"
                else
                    iconFormat = "\xE2\x95\xA0"
                end
                
                iconFormat = iconFormat .. " \xE2\x95\x90"
                
                if ModernNavButton(oge.id, iconFormat, oge.isim, seciliSekme[0] == oge.id, imgui.ImVec2(240, 40)) then 
                    seciliSekme[0] = oge.id 
                end
                imgui.Dummy(imgui.ImVec2(0, 2))
            end
            imgui.Dummy(imgui.ImVec2(0, 10))
        end
        imgui.EndChild()

        imgui.SetCursorPos(imgui.ImVec2(20, wSize.y - 30))
        imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.70, 1.0), "[" .. getKeyName(seciliKisayol[0]) .. "] OPEN / CLOSE")
        
        bgDrawList:AddLine(imgui.ImVec2(wPos.x + 280, wPos.y + 85), imgui.ImVec2(wPos.x + 280, wPos.y + wSize.y - 20), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.10)), 1.0)
        
        imgui.SetCursorPos(imgui.ImVec2(300, 85))
        imgui.BeginChild("Content", imgui.ImVec2(wSize.x - 320, wSize.y - 105), false)
        
        if seciliSekme[0] == 1 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "ANA SAYFA & GENEL BAKIS")
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "SAMP icin gelistirilmis cok amacli kontrol ve otomasyon arayuzu.")
            imgui.Dummy(imgui.ImVec2(0, 20))

            imgui.BeginChild("AnaSayfaSolSutun", imgui.ImVec2(320, 0), false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "SISTEM DURUMU")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if sampev_yuklu then
                imgui.TextColored(imgui.ImVec4(0.4, 1.0, 0.5, 1.0), "Aktif")
                imgui.SameLine()
                imgui.Text("Tum moduller ve SAMP.Lua entegrasyonu sorunsuz calisiyor.")
            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "Uyari")
                imgui.SameLine()
                imgui.Text("SAMP.Lua kutuphanesi eksik. Bazi islevler calismayabilir.")
            end
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Guncel Versiyon: v" .. SURUM)
            
            imgui.Dummy(imgui.ImVec2(0, 20))

            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "YAPIMCI & ILETISIM")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            DrawStat("Yapimci", "Jakuzi", 150)
            DrawStat("Discord", "reyax.", 150, imgui.ImVec4(0.5, 0.6, 0.9, 1.0))
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Discord Sunucusu:")
            if AnimButton("https://discord.gg/gMDEtNw5ac", imgui.ImVec2(-1, 35)) then
                os.execute("start https://discord.gg/gMDEtNw5ac")
            end
            imgui.EndChild()

            imgui.SameLine(0, 20)
            
            imgui.BeginChild("AnaSayfaSagSutun", imgui.ImVec2(0, 0), false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "OZELLIKLER & BILGI")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextWrapped("Bu panel, rol yapma (RP) sunucularinda ve genel SAMP kullaniminda islerinizi hizlandirmak uzere tasarlanmistir. Tum moduller entegre ve optimize sekilde calisir.")
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.BulletText("Otomatik Mesaj & Reklam Botu")
            imgui.BulletText("Etkilesimli Canli Sohbet Logu")
            imgui.BulletText("Kapsamli Blackjack & Zar Hesaplayici")
            imgui.BulletText("Cevresel Oyuncu ve Arac Algilama")
            imgui.BulletText("Dinamik Tema ve Animasyon Yonetimi")
            imgui.EndChild()

        elseif seciliSekme[0] == 2 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "KARAKTER PROFILI")
            BilgiKutusu("Oyun ici karakter ve lisans bilgilerinizi anlik olarak listeler.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
                if AnimButton("Bilgileri Yenile", imgui.ImVec2(180, 35)) then sampSendChat("/karakter") end
                imgui.SameLine()
                if AnimButton("Kimligi Goster", imgui.ImVec2(180, 35)) then 
                    local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                    if res then sampSendChat("/kimlikgoster " .. myId) end 
                end
                imgui.SameLine()
                if AnimButton("Lisanslari Goster", imgui.ImVec2(180, 35)) then 
                    local res, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                    if res then sampSendChat("/ehliyetgoster " .. myId) end 
                end
            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "Oyuna baglanmadan islem yapamazsiniz.")
            end
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.BeginChild("ProfilSolCol", imgui.ImVec2(350, 0), false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KISISEL BILGILER")
            imgui.Separator()
            DrawStat("Isim", charStats.isim, 160)
            DrawStat("Vatandaslik No", charStats.tc_no, 160)
            DrawStat("Uyruk", charStats.uyruk, 160)
            DrawStat("Cinsiyet", charStats.cinsiyet, 160)
            DrawStat("Dogum Tarihi", charStats.dogum, 160)
            DrawStat("Medeni Durum", charStats.medeni, 160)
            DrawStat("Es", charStats.es, 160)
            DrawStat("Telefon", charStats.telefon, 160)

            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KARIYER & BIRLIK")
            imgui.Separator()
            DrawStat("Seviye", charStats.seviye, 160)
            DrawStat("EXP", charStats.exp, 160)
            DrawStat("Oynama Saati", charStats.saat, 160)
            DrawStat("Birlik", charStats.birlik, 160)
            DrawStat("Rutbe", charStats.rutbe, 160)
            DrawStat("Meslek", charStats.meslek, 160)
            imgui.EndChild()
            
            imgui.SameLine(0, 15)
            
            imgui.BeginChild("ProfilSagCol", imgui.ImVec2(0, 0), false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "EKONOMI & VARLIK")
            imgui.Separator()
            DrawStat("Nakit Para", charStats.para, 160)
            DrawStat("Banka Hesabi", charStats.banka, 160)
            DrawStat("Market Bakiye", charStats.market, 160)
            DrawStat("VIP Durumu", charStats.vip, 160)
            DrawStat("Payday Suresi", charStats.payday, 160)
            DrawStat("Maas Suresi", charStats.maas, 160)

            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "SAGLIK DURUMU")
            imgui.Separator()
            local hpStr = charStats.can:gsub(",", ".")
            local hpNum = tonumber(hpStr) or 0
            local arStr = charStats.zirh:gsub(",", ".")
            local arNum = tonumber(arStr) or 0
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Can Durumu:")
            imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.8, 0.3, 0.3, 1.0))
            imgui.ProgressBar(math.min(1.0, hpNum / 100.0), imgui.ImVec2(-1, 25), tostring(hpNum))
            imgui.PopStyleColor()
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Zirh Durumu:")
            imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(0.6, 0.6, 0.6, 1.0))
            imgui.ProgressBar(math.min(1.0, arNum / 100.0), imgui.ImVec2(-1, 25), tostring(arNum))
            imgui.PopStyleColor()
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "LISANSLAR")
            imgui.Separator()
            DrawStat("Ehliyet", charStats.ehliyet, 160)
            DrawStat("Ucus Lisansi", charStats.ucus, 160)
            DrawStat("Silah Ruhsati", charStats.silah, 160)
            imgui.EndChild()

        elseif seciliSekme[0] == 3 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "OTURUM ISTATISTIKLERI")
            BilgiKutusu("Mevcut oturumdaki fiziksel aktiviteleri ve finansal verileri gosterir.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            local runTime = os.time() - sesStartT
            local saat = math.floor(runTime / 3600)
            local dk = math.floor((runTime % 3600) / 60)
            
            imgui.BeginChild("StatSolCol", imgui.ImVec2(350, 0), false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "ZAMAN & ETKILESIM")
            imgui.Separator()
            DrawStat("Gecen Sure", string.format("%d saat, %d dakika", saat, dk), 200)
            DrawStat("AFK Kalinan Sure", string.format("%d dakika", math.floor(sesAfkTime / 60)), 200)
            DrawStat("Sohbete Yazilanlar", tostring(sesMsgCount) .. " mesaj", 200)
            DrawStat("Ateslenen Mermi", tostring(sesShotsFired) .. " el", 200)
            DrawStat("Görülen Oyuncular", tostring(#sesPlayersSeen) .. " kisi", 200)
            imgui.EndChild()

            imgui.SameLine(0, 15)

            imgui.BeginChild("StatSagCol", imgui.ImVec2(0, 0), false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "FIZIKSEL & EKONOMIK")
            imgui.Separator()
            DrawStat("Yaya Gidilen Mesafe", string.format("%.2f km", sesFootDist / 1000.0), 200)
            DrawStat("Aracla Gidilen Mesafe", string.format("%.2f km", sesCarDist / 1000.0), 200)
            DrawStat("Maksimum Hiz", string.format("%.1f km/h", sesMaxSpeed), 200, imgui.ImVec4(1.0, 0.4, 0.4, 1.0))
            DrawStat("Binilen Araclar", tostring(sesCarsUsed) .. " adet", 200)
            imgui.Dummy(imgui.ImVec2(0, 10))
            DrawStat("Kazanilan Ciro", "$" .. formatNumber(sesMoneyEarned), 200, imgui.ImVec4(0.4, 1.0, 0.4, 1.0))
            DrawStat("Kaybedilen Para", "$" .. formatNumber(sesMoneyLost), 200, imgui.ImVec4(1.0, 0.4, 0.4, 1.0))
            imgui.EndChild()

        elseif seciliSekme[0] == 4 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "CANLI SOHBET & LOG")
            BilgiKutusu("Sohbet gecmisini kaydetmenizi veya kopyalamanizi saglar. Islem icin satira sag tiklayin.")
            
            imgui.SameLine(imgui.GetWindowContentRegionWidth() - 220)
            if AnimButton("Logu Kaydet", imgui.ImVec2(220, 35)) then
                local path = getWorkingDirectory() .. "\\chatlog" .. chatLogCount[0] .. ".txt"
                local f = io.open(path, "w")
                if f then 
                    f:write("--- CHATLOG " .. chatLogCount[0] .. " ---\n")
                    for _, log in ipairs(chatLog) do f:write(log.raw .. "\n") end
                    f:close()
                    sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Sohbet " .. path .. " adresine kaydedildi.", -1)
                    chatLogCount[0] = chatLogCount[0] + 1
                    ayarlariKaydet() 
                end
            end
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.12, 0.12, 1.0))
            imgui.BeginChild("ChatHistory", imgui.ImVec2(0, -55), false)
            for i, log in ipairs(chatLog) do
                imgui.PushTextWrapPos(imgui.GetWindowWidth() - 15)
                imgui.TextUnformatted(log.txt)
                imgui.PopTextWrapPos()
                
                if imgui.BeginPopupContextItem("ChatIslem##"..i) then
                    if imgui.Button("Bu Satiri Kopyala") then
                        imgui.SetClipboardText(u8_decode(log.raw))
                        sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Satir panoya kopyalandi.", -1)
                        imgui.CloseCurrentPopup()
                    end
                    imgui.EndPopup()
                end
                
                imgui.GetWindowDrawList():AddLine(
                    imgui.ImVec2(imgui.GetCursorScreenPos().x, imgui.GetCursorScreenPos().y),
                    imgui.ImVec2(imgui.GetCursorScreenPos().x + imgui.GetWindowWidth() - 30, imgui.GetCursorScreenPos().y),
                    imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.05)), 1.0)
                imgui.Dummy(imgui.ImVec2(0, 4))
            end
            if imgui.GetScrollY() >= imgui.GetScrollMaxY() then imgui.SetScrollHereY(1.0) end
            imgui.EndChild()
            imgui.PopStyleColor()
            
            imgui.PushItemWidth(180)
            if #currentNearbyNames > 0 then imgui.Combo("##NearbyChat", seciliChatTarget, nearbyComboItems, #currentNearbyNames) 
            else imgui.Combo("##NearbyChat", seciliChatTarget, nearbyComboItems, 1) end
            imgui.PopItemWidth()
            imgui.SameLine()
            
            imgui.PushItemWidth(250)
            imgui.InputText("Mesaj", chatMesajInput, 256)
            imgui.PopItemWidth()
            imgui.SameLine()
            
            if AnimButton("PM At", imgui.ImVec2(80, 35)) then
                if #currentNearbyIDs > 0 then
                    local tid = currentNearbyIDs[seciliChatTarget[0] + 1]
                    local msg = ffi.string(chatMesajInput)
                    if msg ~= "" then sampSendChat("/pm " .. tid .. " " .. u8_decode(msg)); ffi.copy(chatMesajInput, "") end
                end
            end
            imgui.SameLine()
            if AnimButton("Fisilda", imgui.ImVec2(80, 35)) then
                if #currentNearbyIDs > 0 then
                    local tid = currentNearbyIDs[seciliChatTarget[0] + 1]
                    local msg = ffi.string(chatMesajInput)
                    if msg ~= "" then sampSendChat("/w " .. tid .. " " .. u8_decode(msg)); ffi.copy(chatMesajInput, "") end
                end
            end

        elseif seciliSekme[0] == 5 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "OTOMATIK MESAJ BOTU")
            BilgiKutusu("Belirtilen sure araliklarinda arka planda otomatik mesaj gonderir.")
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushItemWidth(150)
            imgui.InputText("Isim Belirle", otoIsim, 128)
            imgui.SameLine()
            imgui.PushItemWidth(350)
            imgui.InputText("Komut (/ ile)", otoKomut, 256)
            imgui.PopItemWidth()
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.PushItemWidth(100)
            imgui.SliderInt("Gun", otoGun, 0, 7)
            imgui.SameLine()
            imgui.SliderInt("Saat", otoSaat, 0, 23)
            imgui.SameLine()
            imgui.SliderInt("Dk.", otoDakika, 0, 59)
            imgui.SameLine()
            imgui.SliderInt("Sn.", otoSaniye, 0, 59)
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if AnimButton("YENI GOREV EKLE", imgui.ImVec2(-1, 35)) then
                local isimS = ffi.string(otoIsim)
                local komS = ffi.string(otoKomut)
                if isimS ~= "" and komS ~= "" then
                    if otoGun[0] == 0 and otoSaat[0] == 0 and otoDakika[0] == 0 and otoSaniye[0] == 0 then
                        sampAddChatMessage("{FF0000}[Uyari] {FFFFFF}Lutfen gecerli bir sure ayarlayiniz.", -1)
                    else
                        table.insert(otoMesajlar, { isim = isimS, komut = komS, gun = otoGun[0], saat = otoSaat[0], dakika = otoDakika[0], saniye = otoSaniye[0], aktif = false, sonraki_zaman = 0 })
                        ayarlariKaydet()
                        ffi.copy(otoIsim, ""); ffi.copy(otoKomut, ""); otoGun[0]=0; otoSaat[0]=0; otoDakika[0]=5; otoSaniye[0]=0
                    end
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "GOREV LISTESI")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if #otoMesajlar == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Aktif gorev bulunmuyor.")
            else
                for i, v in ipairs(otoMesajlar) do
                    local dl = imgui.GetWindowDrawList()
                    local cp = imgui.GetCursorScreenPos()
                    local statusColor = v.aktif and imgui.GetColorU32Vec4(imgui.ImVec4(0.4, 1.0, 0.4, 1.0)) or imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 0.4, 0.4, 1.0))
                    dl:AddCircleFilled(imgui.ImVec2(cp.x + 10, cp.y + 18), 8.0, statusColor)
                    
                    imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPos().x + 25, imgui.GetCursorPos().y + 5))
                    imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), string.format("%s (Sure: %dG %dS %dD %dSn)", v.isim, v.gun, v.saat, v.dakika, v.saniye))
                    
                    imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 170, imgui.GetCursorPos().y - 32))
                    
                    if AnimButton((v.aktif and "Durdur##" or "Baslat##") .. i, imgui.ImVec2(80, 30)) then
                        v.aktif = not v.aktif
                        if v.aktif then
                            v.sonraki_zaman = os.time() + (v.gun * 86400) + (v.saat * 3600) + (v.dakika * 60) + v.saniye
                            sampAddChatMessage("{4A90E2}[Bot] {FFFFFF}" .. v.isim .. " botu aktif edildi.", -1)
                        else
                            sampAddChatMessage("{4A90E2}[Bot] {FFFFFF}" .. v.isim .. " botu durduruldu.", -1)
                        end
                        ayarlariKaydet()
                    end
                    imgui.SameLine()
                    if AnimButton("Sil##otodelete"..i, imgui.ImVec2(50, 30)) then
                        table.remove(otoMesajlar, i)
                        ayarlariKaydet()
                    end
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.Separator()
                end
            end

        elseif seciliSekme[0] == 6 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "GARAJ VE ARAC KONTROLLERI")
            BilgiKutusu("Arac fonksiyonlarinin uzaktan veya iceriden hizli yonetimini saglar.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
                if AnimButton("Cevredeki Araclari Tara / Yenile", imgui.ImVec2(-1, 35)) then sampSendChat("/arac liste") end
                imgui.Dummy(imgui.ImVec2(0, 5))
                
                imgui.PushItemWidth(300)
                if comboAracCount > 0 then imgui.Combo("##AracSecici", seciliAracIndex, comboAracItems, comboAracCount)
                else local d = ffi.new('const char*[1]', {ffi.cast("const char*", "Cevrede arac bulunamadi")}); imgui.Combo("##AracSecici", seciliAracIndex, d, 1) end
                imgui.PopItemWidth()
                imgui.SameLine()
                
                if AnimButton("Kilitle / Ac", imgui.ImVec2(120, 35)) then
                    if #aktifAraclar > 0 then sampSendChat("/akilit " .. tostring(aktifAraclar[seciliAracIndex[0] + 1].id)) end
                end
                imgui.SameLine()
                if AnimButton("GPS'de Bul", imgui.ImVec2(120, 35)) then
                    if #aktifAraclar > 0 then sampSendChat("/agps " .. tostring(aktifAraclar[seciliAracIndex[0] + 1].id)) end
                end
                
                imgui.Dummy(imgui.ImVec2(0, 15))
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "ARAC DISI KONTROLLER")
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 5))
                if AnimButton("Yanindaki Araci Kilitle / Ac [ N Tusu ]", imgui.ImVec2(-1, 35)) then table.insert(tusKuyrugu, vkeys.VK_N) end
                imgui.Dummy(imgui.ImVec2(0, 2))
                if AnimButton("Kaputu Ac", imgui.ImVec2(150, 35)) then sampSendChat("/arac kaput") end
                imgui.SameLine()
                if AnimButton("Bagaji Ac", imgui.ImVec2(150, 35)) then sampSendChat("/arac bagaj") end
                imgui.SameLine()
                if AnimButton("Park Et", imgui.ImVec2(100, 35)) then sampSendChat("/park") end
                imgui.SameLine()
                if AnimButton("Sakla", imgui.ImVec2(100, 35)) then sampSendChat("/arac sakla") end
                
                imgui.Dummy(imgui.ImVec2(0, 15))
                
                if isCharInAnyCar(PLAYER_PED) then
                    imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "ARAC ICI KONTROLLER")
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    
                    local car = storeCarCharIsInNoSave(PLAYER_PED)
                    local hPercent = math.max(0, math.min(1, (getCarHealth(car) - 250) / 750))
                    
                    imgui.BeginChild("AracIciSolCol", imgui.ImVec2(340, 0), false)
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Arac Genel Durumu:")
                    imgui.ProgressBar(hPercent, imgui.ImVec2(310, 25), string.format("Saglamlik: %d%%", math.floor(hPercent * 100)))
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    
                    if AnimButton("Motoru Calistir / Durdur [ Y ]", imgui.ImVec2(310, 35)) then table.insert(tusKuyrugu, vkeys.VK_Y) end 
                    if AnimButton("Farlari Yak / Sondur [ N ]", imgui.ImVec2(310, 35)) then table.insert(tusKuyrugu, vkeys.VK_N) end 
                    if AnimButton("Kapilari Iceriden Kilitle", imgui.ImVec2(310, 35)) then sampSendChat("/arac kilit") end
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    if imgui.Checkbox("Kamerayi Sabitle (Sarsinti Engelle)", kameraSabitleAktif) then ayarlariKaydet() end

                    imgui.Dummy(imgui.ImVec2(0, 10))
                    imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "HIZ SABITLEYICI (CRUISE)")
                    imgui.Separator()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Durum: ")
                    imgui.SameLine()
                    
                    if isCruiseActive then imgui.TextColored(imgui.ImVec4(0.4, 1.0, 0.4, 1.0), "Aktif (" .. math.floor(cruiseSpeed * 3.6) .. " km/h)")
                    else imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "Devre Disi") end
                    
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Tetikleyici: ")
                    imgui.SameLine()
                    if AnimButton(bekleCruiseTusu and "Basin..." or getKeyName(seciliCruiseKisayol[0]), imgui.ImVec2(100, 30)) then
                        bekleCruiseTusu = true; beklePanelTusu = false; bekleMouseTusu = false; bekleSinematikTusu = false; bekleScoreboardTusu = false; bindGecikmesi = os.clock() + 0.2
                    end
                    imgui.EndChild()
                    
                    imgui.SameLine(0, 15)
                    
                    imgui.BeginChild("AracIciSagCol", imgui.ImVec2(0, 0), false)
                    imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "HASAR SENSORU")
                    imgui.Separator()
                    
                    local dl = imgui.GetWindowDrawList()
                    local p = imgui.GetCursorScreenPos()
                    local cx, cy = p.x + 80, p.y + 70
                    
                    local cGreen = imgui.GetColorU32Vec4(imgui.ImVec4(0.4, 1.0, 0.4, 1.0))
                    local cRed = imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 0.4, 0.4, 1.0))
                    local cBody = imgui.GetColorU32Vec4(imgui.ImVec4(0.15, 0.15, 0.15, 1.0))
                    local cWin = imgui.GetColorU32Vec4(imgui.ImVec4(0.08, 0.08, 0.08, 1.0))
                    local cText = imgui.GetColorU32Vec4(imgui.ImVec4(0.85, 0.85, 0.85, 1.0))
                    
                    local fl = isCarTireBurst(car, 0)
                    local rl = isCarTireBurst(car, 1)
                    local fr = isCarTireBurst(car, 2)
                    local rr = isCarTireBurst(car, 3)
                    local function tC(b) return b and cRed or cGreen end
                    
                    dl:AddRectFilled(imgui.ImVec2(cx - 30, cy - 60), imgui.ImVec2(cx + 30, cy + 60), cBody, 8.0)
                    dl:AddRectFilled(imgui.ImVec2(cx - 24, cy - 25), imgui.ImVec2(cx + 24, cy + 30), cWin, 4.0)
                    
                    dl:AddRectFilled(imgui.ImVec2(cx - 42, cy - 45), imgui.ImVec2(cx - 30, cy - 15), tC(fl), 4.0)
                    dl:AddRectFilled(imgui.ImVec2(cx + 30, cy - 45), imgui.ImVec2(cx + 42, cy - 15), tC(fr), 4.0)
                    dl:AddRectFilled(imgui.ImVec2(cx - 42, cy + 15), imgui.ImVec2(cx - 30, cy + 45), tC(rl), 4.0)
                    dl:AddRectFilled(imgui.ImVec2(cx + 30, cy + 15), imgui.ImVec2(cx + 42, cy + 45), tC(rr), 4.0)
                    
                    local eC = (hPercent > 0.5) and cGreen or ((hPercent > 0.25) and imgui.GetColorU32Vec4(imgui.ImVec4(1.0, 1.0, 0.4, 1.0)) or cRed)
                    dl:AddCircleFilled(imgui.ImVec2(cx, cy - 40), 6.0, eC)
                    
                    dl:AddLine(imgui.ImVec2(cx + 8, cy - 40), imgui.ImVec2(cx + 60, cy - 40), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.2)), 1.0)
                    dl:AddText(imgui.ImVec2(cx + 65, cy - 47), cText, "Motor")
                    dl:AddLine(imgui.ImVec2(cx + 42, cy - 30), imgui.ImVec2(cx + 60, cy - 10), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.2)), 1.0)
                    dl:AddText(imgui.ImVec2(cx + 65, cy - 17), cText, "On Lastik")
                    dl:AddLine(imgui.ImVec2(cx + 42, cy + 30), imgui.ImVec2(cx + 60, cy + 10), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.2)), 1.0)
                    dl:AddText(imgui.ImVec2(cx + 65, cy + 3), cText, "Arka Lastik")
                    
                    imgui.Dummy(imgui.ImVec2(0, 160))
                    imgui.EndChild()
                else
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Arac ici ayarlari gormek icin bir aracta olmalisiniz.")
                end
            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "Oyuna baglanmadan islem yapamazsiniz.")
            end

        elseif seciliSekme[0] == 7 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "ROL KOMUTLARI")
            BilgiKutusu("Yakindaki oyuncularla hizli etkilesim kurmanizi saglar. Formatta {isim} ve {id} degiskenleri kullanilabilir.")
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.PushItemWidth(140)
            imgui.InputText("Buton Adi", inputRpIsim, 256)
            imgui.SameLine()
            imgui.PushItemWidth(250)
            imgui.InputText("Komut", inputRpKomut, 256)
            imgui.PopItemWidth()
            imgui.PopItemWidth()
            imgui.SameLine()
            
            if duzenleRpIndex == 0 then
                if AnimButton("EKLE", imgui.ImVec2(80, 30)) then
                    local isimStr, komutStr = ffi.string(inputRpIsim), ffi.string(inputRpKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        table.insert(rpButonlar, {isim = isimStr, komut = komutStr})
                        ayarlariKaydet()
                        ffi.copy(inputRpIsim, "")
                        ffi.copy(inputRpKomut, "")
                    end
                end
            else
                if AnimButton("KAYDET", imgui.ImVec2(80, 30)) then
                    local isimStr, komutStr = ffi.string(inputRpIsim), ffi.string(inputRpKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        rpButonlar[duzenleRpIndex].isim = isimStr
                        rpButonlar[duzenleRpIndex].komut = komutStr
                        ayarlariKaydet()
                        duzenleRpIndex = 0
                        ffi.copy(inputRpIsim, "")
                        ffi.copy(inputRpKomut, "")
                    end
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KAYITLI KOMUTLAR")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if #rpButonlar == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Henuz bir veri eklenmemis.")
            else
                for i, val in ipairs(rpButonlar) do
                    imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), val.isim)
                    imgui.SameLine(140)
                    local kisaKomut = val.komut
                    if #kisaKomut > 40 then kisaKomut = kisaKomut:sub(1, 40) .. "..." end
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), kisaKomut)
                    
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 115) 
                    if AnimButton("Duzenle##rpduz"..i, imgui.ImVec2(75, 28)) then
                        duzenleRpIndex = i
                        ffi.copy(inputRpIsim, val.isim)
                        ffi.copy(inputRpKomut, val.komut)
                    end
                    imgui.SameLine()
                    if AnimButton("X##rpsil"..i, imgui.ImVec2(30, 28)) then
                        if duzenleRpIndex == i then
                            duzenleRpIndex = 0
                            ffi.copy(inputRpIsim, "")
                            ffi.copy(inputRpKomut, "")
                        end
                        table.remove(rpButonlar, i)
                        ayarlariKaydet()
                    end
                    imgui.Dummy(imgui.ImVec2(0, 2))
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 20))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "MENZILDEKI OYUNCULAR (15M)")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
                local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
                local oyuncuBulundu = false
                for _, ped in ipairs(getAllChars()) do
                    if ped ~= PLAYER_PED then
                        local isPlayer, id = sampGetPlayerIdByCharHandle(ped)
                        if isPlayer then
                            local px, py, pz = getCharCoordinates(ped)
                            local dist = getDistanceBetweenCoords3d(myX, myY, myZ, px, py, pz)
                            if dist <= 15.0 then
                                oyuncuBulundu = true
                                local name = sampGetPlayerNickname(id):gsub("_", " ")
                                imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), string.format("[%d] %s", id, name))
                                imgui.SameLine(250)
                                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), string.format("%.1f metre", dist))
                                imgui.Dummy(imgui.ImVec2(0, 5))
                                
                                for i, b in ipairs(rpButonlar) do
                                    if AnimButton(b.isim .. "##b"..id.."_"..i, imgui.ImVec2(120, 28)) then
                                        local finalCmd = b.komut:gsub("{isim}", name):gsub("{id}", tostring(id))
                                        sampSendChat(u8_decode(finalCmd))
                                    end
                                    if i % 5 ~= 0 and i ~= #rpButonlar then imgui.SameLine() end
                                end
                                if #rpButonlar > 0 then imgui.Dummy(imgui.ImVec2(0, 10)) end
                            end
                        end
                    end
                end
                if not oyuncuBulundu then imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Cevrede etkilesime girilecek oyuncu bulunamadi.") end
            else
                imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "Oyuna baglanmadan islem yapamazsiniz.")
            end

        elseif seciliSekme[0] == 8 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "ANIMASYONLAR")
            BilgiKutusu("Kayitli animasyonlari tek tikla uygulamanizi saglar.")
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.PushItemWidth(180)
            imgui.InputText("Animasyon Adi", inputAnimIsim, 256)
            imgui.SameLine()
            imgui.PushItemWidth(300)
            imgui.InputText("Komut (/ ile)", inputAnimKomut, 256)
            imgui.PopItemWidth()
            imgui.SameLine()
            
            if duzenleAnimIndex == 0 then
                if AnimButton("EKLE##animEkle", imgui.ImVec2(80, 30)) then
                    local isimStr, komutStr = ffi.string(inputAnimIsim), ffi.string(inputAnimKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        table.insert(animButonlar, {isim = isimStr, komut = komutStr})
                        animasyonlariKaydet()
                        ffi.copy(inputAnimIsim, "")
                        ffi.copy(inputAnimKomut, "")
                    end
                end
            else
                if AnimButton("KAYDET##animGuncelle", imgui.ImVec2(80, 30)) then
                    local isimStr, komutStr = ffi.string(inputAnimIsim), ffi.string(inputAnimKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        animButonlar[duzenleAnimIndex].isim = isimStr
                        animButonlar[duzenleAnimIndex].komut = komutStr
                        animasyonlariKaydet()
                        duzenleAnimIndex = 0
                        ffi.copy(inputAnimIsim, "")
                        ffi.copy(inputAnimKomut, "")
                    end
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KAYITLI ANIMASYONLAR")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if #animButonlar == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Liste su an bos.")
            else
                for i, val in ipairs(animButonlar) do
                    if AnimButton(val.isim .. "##btn_anim" .. i, imgui.ImVec2(440, 38)) then sampSendChat(u8_decode(val.komut)) end
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 115)
                    
                    if AnimButton("Duzenle##animduz"..i, imgui.ImVec2(75, 38)) then
                        duzenleAnimIndex = i
                        ffi.copy(inputAnimIsim, val.isim)
                        ffi.copy(inputAnimKomut, val.komut)
                    end
                    imgui.SameLine()
                    if AnimButton("X##animsil" .. i, imgui.ImVec2(30, 38)) then
                        if duzenleAnimIndex == i then
                            duzenleAnimIndex = 0
                            ffi.copy(inputAnimIsim, "")
                            ffi.copy(inputAnimKomut, "")
                        end
                        table.remove(animButonlar, i)
                        animasyonlariKaydet()
                    end
                end
            end
            imgui.Dummy(imgui.ImVec2(0, 15))
            if AnimButton("TUMUNU DURDUR [ /dans ]", imgui.ImVec2(-1, 40)) then sampSendChat("/dans") end

        elseif seciliSekme[0] == 9 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "NOT DEFTERI")
            BilgiKutusu("Oyun ici alinan notlari dosyaniza kaydeder.")
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            if AnimButton("DEGISIKLIKLERI KAYDET", imgui.ImVec2(200, 35)) then ajandaKaydet() end
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "(Otomatik kaydetmez, butona basiniz)")
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.InputTextMultiline("##ajandainput", ajandaBuffer, ffi.sizeof(ajandaBuffer), imgui.ImVec2(-1, 500))

        elseif seciliSekme[0] == 10 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "HESAP MAKINESI")
            BilgiKutusu("Oyun ici temel matematiksel islemleri gerceklestirir.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Guncel Sonuc:")
            if fontComboCount > 0 and mevcutFontPointers[seciliFontIndex[0] + 1] then imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1]) end
            imgui.TextColored(imgui.ImVec4(0.4, 1.0, 0.4, 1.0), string.format("$ %s", formatNumber(math.floor(calcSonuc))))
            if fontComboCount > 0 and mevcutFontPointers[seciliFontIndex[0] + 1] then imgui.PopFont() end
            
            imgui.Dummy(imgui.ImVec2(0, 20))
            imgui.PushItemWidth(250)
            imgui.InputInt("1. Deger", calcMiktar1)
            imgui.InputInt("2. Deger", calcMiktar2)
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if AnimButton("Topla (+)", imgui.ImVec2(110, 38)) then calcSonuc = calcMiktar1[0] + calcMiktar2[0] end
            imgui.SameLine()
            if AnimButton("Cikar (-)", imgui.ImVec2(110, 38)) then calcSonuc = calcMiktar1[0] - calcMiktar2[0] end
            imgui.SameLine()
            if AnimButton("Carp (x)", imgui.ImVec2(110, 38)) then calcSonuc = calcMiktar1[0] * calcMiktar2[0] end
            imgui.SameLine()
            if AnimButton("Bol (/)", imgui.ImVec2(110, 38)) then if calcMiktar2[0] ~= 0 then calcSonuc = calcMiktar1[0] / calcMiktar2[0] else calcSonuc = 0 end end

        elseif seciliSekme[0] == 11 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "ATMOSFER VE ZAMAN")
            BilgiKutusu("Gorus mesafesi, saat ve hava durumu gibi yerel cevre ayarlarini degistirir.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "GORUS MESAFESI (DRAW DISTANCE)")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if AnimButton("Performans Modu (FPS)", imgui.ImVec2(200, 35)) then
                ffi.cast("float*", 0x8DCE38)[0] = 300.0
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Gorus mesafesi performans modu icin dusuruldu.", -1)
            end
            imgui.SameLine()
            if AnimButton("Ultra Gorus (SS Modu)", imgui.ImVec2(200, 35)) then
                ffi.cast("float*", 0x8DCE38)[0] = 3000.0
                forceWeatherNow(1) 
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Gorus mesafesi maksimum seviyeye cikarildi.", -1)
            end
            imgui.SameLine()
            if AnimButton("Varsayilana Don", imgui.ImVec2(150, 35)) then
                ffi.cast("float*", 0x8DCE38)[0] = 800.0
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Gorus mesafesi varsayilan degere donduruldu.", -1)
            end
            
            imgui.Dummy(imgui.ImVec2(0, 20))
            
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "ZAMAN & SAAT AYARI")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.PushItemWidth(350)
            imgui.SliderInt("Istenilen Saat", seciliSaat, 0, 23)
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if AnimButton("Zamani Sabitle", imgui.ImVec2(200, 35)) then
                g_SabitZaman = seciliSaat[0]
                patch_samp_time_set(true)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Zaman basariyla sabitlendi.", -1)
            end
            imgui.SameLine()
            if AnimButton("Sunucu Senkronizasyonu", imgui.ImVec2(200, 35)) then
                g_SabitZaman = nil
                patch_samp_time_set(false)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Zaman ayari sunucu ile senkronize edildi.", -1)
            end
            
            imgui.Dummy(imgui.ImVec2(0, 20))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "HAVA DURUMU MODELI")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.PushItemWidth(350)
            imgui.Combo("Atmosfer Secimi", seciliHava, havaDurumuItems, #havaDurumuIsimleri)
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if AnimButton("Uygula", imgui.ImVec2(200, 35)) then
                local hedefID = havaDurumuIDs[seciliHava[0] + 1]
                forceWeatherNow(hedefID)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Hava durumu basariyla degistirildi.", -1)
            end

        elseif seciliSekme[0] == 12 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "BLACKJACK & ZAR ASISTANI")
            BilgiKutusu("Sohbetteki zar verilerini okuyarak oyuncu puanlarini listeler ve 21'i gecme riskini hesaplar.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if AnimButton("Cift Zar At (/zar cift)", imgui.ImVec2(180, 35)) then sampSendChat("/zar cift") end
            imgui.SameLine()
            if AnimButton("Tek Zar At (/zar tek)", imgui.ImVec2(180, 35)) then sampSendChat("/zar tek") end
            imgui.SameLine()
            if AnimButton("Verileri Temizle", imgui.ImVec2(150, 35)) then bjPlayers = {}; bjData = {} end
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if #bjPlayers == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Henuz zar atilmadi, veriler bekleniyor...")
            else
                for i, pName in ipairs(bjPlayers) do
                    local data = bjData[pName]
                    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.12, 0.12, 0.12, 1.0))
                    imgui.BeginChild("kisi_"..i, imgui.ImVec2(0, 130), false)
                    
                    imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "Oyuncu: " .. pName)
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 60)
                    if AnimButton("Sifirla##" .. i, imgui.ImVec2(60, 24)) then
                        bjData[pName] = nil
                        table.remove(bjPlayers, i)
                    end
                    imgui.Separator()
                    
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Guncel Puan: ")
                    imgui.SameLine()
                    
                    local cScore = imgui.ImVec4(0.4, 1.0, 0.4, 1.0)
                    local durumMetni = "GUVENLI BOLGE"
                    if data.toplam == 21 then 
                        cScore = imgui.ImVec4(1.0, 0.8, 0.2, 1.0)
                        durumMetni = "BLACKJACK MUKEMMEL"
                    elseif data.toplam > 21 then 
                        cScore = imgui.ImVec4(1.0, 0.4, 0.4, 1.0) 
                        durumMetni = "LIMIT ASIMI"
                    elseif data.toplam >= 17 then 
                        cScore = imgui.ImVec4(1.0, 0.8, 0.2, 1.0)
                        durumMetni = "RISKLI BOLGE"
                    end
                    imgui.TextColored(cScore, tostring(data.toplam) .. " [" .. durumMetni .. "]")
                    
                    local riskTek = getRiskTekZar(data.toplam)
                    local riskCift = getRiskCiftZar(data.toplam)
                    
                    imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0))
                    imgui.ProgressBar(riskTek / 100.0, imgui.ImVec2(300, 18), string.format("1 Zarda Asim: %%%.1f", riskTek))
                    imgui.SameLine()
                    imgui.ProgressBar(riskCift / 100.0, imgui.ImVec2(300, 18), string.format("2 Zarda Asim: %%%.1f", riskCift))
                    imgui.PopStyleColor()
                    
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), string.format("Atilan Tekli: %d | Yapilan Ciftli: %d", data.tekli, data.ciftli))
                    imgui.EndChild()
                    imgui.PopStyleColor()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                end
            end

        elseif seciliSekme[0] == 13 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "OZEL KISAYOLLAR VE MAKROLAR")
            BilgiKutusu("Ozel sunucu komutlarini butonlara veya klavye tuslarina atayarak hizli erisim saglar.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            imgui.PushItemWidth(180)
            imgui.InputText("Buton Ismi", inputIsim, 256)
            imgui.SameLine()
            imgui.PushItemWidth(300)
            imgui.InputText("Komut (/ ile)", inputKomut, 256)
            imgui.PopItemWidth()
            imgui.SameLine()
            
            if duzenleOzelIndex == 0 then
                if AnimButton("EKLE", imgui.ImVec2(80, 30)) then
                    local isimStr, komutStr = ffi.string(inputIsim), ffi.string(inputKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        table.insert(ozelButonlar, {isim = isimStr, komut = komutStr, tus = {}, bekliyor = false})
                        ayarlariKaydet()
                        ffi.copy(inputIsim, "")
                        ffi.copy(inputKomut, "")
                    end
                end
            else
                if AnimButton("KAYDET", imgui.ImVec2(80, 30)) then
                    local isimStr, komutStr = ffi.string(inputIsim), ffi.string(inputKomut)
                    if isimStr ~= "" and komutStr ~= "" then
                        ozelButonlar[duzenleOzelIndex].isim = isimStr
                        ozelButonlar[duzenleOzelIndex].komut = komutStr
                        ayarlariKaydet()
                        duzenleOzelIndex = 0
                        ffi.copy(inputIsim, "")
                        ffi.copy(inputKomut, "")
                    end
                end
            end
            
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KAYITLI BUTONLAR & ATAMALAR")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if #ozelButonlar == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Bu alan su an bos.")
            else
                for i, val in ipairs(ozelButonlar) do
                    if AnimButton(val.isim .. "##btn" .. i, imgui.ImVec2(300, 38)) then sampSendChat(u8_decode(val.komut)) end
                    imgui.SameLine()
                    
                    local btnW = 100
                    local tusYazi = val.bekliyor and "Basin..." or getComboName(val.tus)
                    if AnimButton(tusYazi .. "##btntus" .. i, imgui.ImVec2(btnW, 38)) then
                        val.bekliyor = true
                        bindGecikmesi = os.clock() + 0.2
                    end
                    
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.3, 0.3, 0.8))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(1.0, 0.4, 0.4, 1.0))
                    if AnimButton("X##cleartus"..i, imgui.ImVec2(30, 38)) then 
                        val.tus = {}
                        ayarlariKaydet()
                    end
                    imgui.PopStyleColor(2)
                    if imgui.IsItemHovered() then 
                        imgui.BeginTooltip()
                        imgui.Text("Tus atamasini kaldir")
                        imgui.EndTooltip()
                    end
                    
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 115)
                    
                    if AnimButton("Duzenle##ozduz"..i, imgui.ImVec2(75, 38)) then
                        duzenleOzelIndex = i
                        ffi.copy(inputIsim, val.isim)
                        ffi.copy(inputKomut, val.komut)
                    end
                    imgui.SameLine()
                    if AnimButton("X##ozsil" .. i, imgui.ImVec2(30, 38)) then
                        if duzenleOzelIndex == i then
                            duzenleOzelIndex = 0
                            ffi.copy(inputIsim, "")
                            ffi.copy(inputKomut, "")
                        end
                        table.remove(ozelButonlar, i)
                        ayarlariKaydet()
                    end
                end
            end

        elseif seciliSekme[0] == 14 then 
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "MODULLER VE EK SISTEMLER")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if imgui.CollapsingHeader("Sinematik Cekim Modu") then
                BilgiKutusu("Fare donuslerini pruzsuzlestirir, HUD gizler.")
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Tetikleme Tusu:")
                if AnimButton(bekleSinematikTusu and "Basin..." or getKeyName(seciliSinematikKisayol[0]), imgui.ImVec2(150, 30)) then
                    bekleSinematikTusu = true; beklePanelTusu = false; bekleMouseTusu = false; bekleCruiseTusu = false; bekleScoreboardTusu = false; bindGecikmesi = os.clock() + 0.2
                end
                if sinematikAktif then imgui.TextColored(imgui.ImVec4(0.4, 1.0, 0.4, 1.0), "Durum: AKTIF") else imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "Durum: KAPALI") end
            end

            if imgui.CollapsingHeader("Otomatik Sifre Girici (Auto-Login)") then
                BilgiKutusu("Sunucu giris (Login) pencerelerine sectiginiz sifreyi otomatik yazip bypass eder.")
                if imgui.Checkbox("Auto-Login Modulunu Aktif Et", otoLoginAktif) then ayarlariKaydet() end
                if otoLoginAktif[0] then
                    imgui.PushItemWidth(250)
                    if imgui.InputText("Sifreniz##autologin", otoLoginSifre, 128, imgui.InputTextFlags.Password) then ayarlariKaydet() end
                    imgui.PopItemWidth()
                    imgui.SameLine()
                    if AnimButton("Kaydet##sifrekaydet", imgui.ImVec2(80, 24)) then ayarlariKaydet() end
                end
            end

            if imgui.CollapsingHeader("Dinamik HUD") then
                if imgui.Checkbox("Dinamik HUD'u Aktif Et", dinamikHudAktif) then ayarlariKaydet() end
                if dinamikHudAktif[0] then
                    imgui.SameLine(250)
                    if imgui.Checkbox("Ekrana Sabitle", dinamikHudSabit) then ayarlariKaydet() end
                end
            end
            
            if imgui.CollapsingHeader("Hitmarker") then
                if imgui.Checkbox("Hitmarker ve Sesi Aktif Et", hitmarkerAktif) then ayarlariKaydet() end
            end
            
            if imgui.CollapsingHeader("Sahte Mesaj (Screenshot Modu)") then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Kullanim: /fchat [Renk Kodu] [Mesaj]")
            end
            
            if imgui.CollapsingHeader("Sohbet Radari") then
                imgui.PushItemWidth(200)
                imgui.InputText("Kelime", inputRadar, 128)
                imgui.PopItemWidth()
                imgui.SameLine()
                if AnimButton("Ekle", imgui.ImVec2(80, 30)) then
                    local rStr = ffi.string(inputRadar)
                    if rStr ~= "" then table.insert(radarKelimeler, rStr); ayarlariKaydet(); ffi.copy(inputRadar, "") end
                end
                for i, kelime in ipairs(radarKelimeler) do
                    imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.4, 1.0), "- " .. kelime)
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 40)
                    if AnimButton("X##radarsil"..i, imgui.ImVec2(30, 24)) then table.remove(radarKelimeler, i); ayarlariKaydet() end
                end
            end
            
            if imgui.CollapsingHeader("Mesaj Formatlayici") then
                if imgui.Checkbox("On Ek Modunu Aktif Et", aksanAktif) then ayarlariKaydet() end
                imgui.PushItemWidth(150)
                imgui.InputText("Ek", aksanMetin, 128)
                imgui.PopItemWidth()
                imgui.SameLine()
                if AnimButton("Kaydet##aksan", imgui.ImVec2(80, 30)) then ayarlariKaydet() end
                if imgui.Checkbox("Normal mesajlari /t yap", telsizAktif) then ayarlariKaydet() end
            end
            
            if imgui.CollapsingHeader("Oto PM") then
                if imgui.Checkbox("Modulu Aktif Et", afkAktif) then ayarlariKaydet() end
                imgui.PushItemWidth(150)
                imgui.InputText("Kelime", afkTetikleyici, 128)
                imgui.PopItemWidth()
                imgui.PushItemWidth(300)
                imgui.InputText("Yanit", afkMesaj, 256)
                imgui.PopItemWidth()
                if AnimButton("Kaydet##otopm", imgui.ImVec2(150, 30)) then ayarlariKaydet() end
            end
            
            if imgui.CollapsingHeader("3D Favori Radari") then
                imgui.PushItemWidth(150)
                imgui.InputText("Oyuncu Ismi", yeniKankaIsim, 128)
                imgui.PopItemWidth()
                imgui.SameLine()
                if AnimButton("Ekle##fav", imgui.ImVec2(80, 30)) then
                    local ism = ffi.string(yeniKankaIsim)
                    if ism ~= "" then favoritePlayers[ism] = true; ffi.copy(yeniKankaIsim, "") end
                end
                for name, _ in pairs(favoritePlayers) do
                    imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.4, 1.0), "⭐ " .. name)
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 40)
                    if AnimButton("X##favsil_"..name, imgui.ImVec2(30, 24)) then favoritePlayers[name] = nil end
                end
            end
            
        elseif seciliSekme[0] == 15 then 
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "TEMA VE GORUNUM (KaUI TASARIMI)")
            BilgiKutusu("Arayuz renklerini ve arka planini kisisellestirebilirsiniz.")
            imgui.Dummy(imgui.ImVec2(0, 15))
            
            if imgui.Checkbox("Gelismis Skor Tablosunu Aktif Et (TAB)", ozelScoreboardAktif) then ayarlariKaydet() end
            imgui.Dummy(imgui.ImVec2(0, 5))
            if imgui.Checkbox("Yeni Nesil Isim Etiketleri (Nametags)", ozelNametagAktif) then ayarlariKaydet() end
            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Arayuz Yazi Tipi:")
            imgui.PushItemWidth(250)
            if fontComboCount > 0 then
                if imgui.Combo("##FontSecici", seciliFontIndex, fontComboItems, fontComboCount) then ayarlariKaydet() end
            end
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            if imgui.Checkbox("Gorsel ve Ses Efektleri", sesVeEfektAktif) then ayarlariKaydet() end
            
            imgui.Dummy(imgui.ImVec2(0, 5))
            imgui.PushItemWidth(250)
            if imgui.Combo("Imlec Stili", mouseTip, mouseTipItems, 4) then ayarlariKaydet() end
            imgui.PopItemWidth()
            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Vurgu Rengi Secimi (Menuler / Çizgiler / Parlamalar):")
            if imgui.ColorEdit3("Tema Rengi", temaRengi) then ayarlariKaydet() end
            
            imgui.Dummy(imgui.ImVec2(0, 10))
            imgui.TextColored(imgui.ImVec4(0.65, 0.65, 0.65, 1.0), "* Oyun klasorundeki moonloader klasorune 'arkaplan.jpg' koyarsaniz panele ozel resim arka plan uygular.")
            imgui.TextColored(imgui.ImVec4(0.65, 0.65, 0.65, 1.0), "* Yine moonloader klasorune 'buton_bg.jpg' atarsaniz tum butonlarinizin tasarimi o resim ile donatilir.")
            
            imgui.Dummy(imgui.ImVec2(0, 20))
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KONTROL TUSLARI")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Paneli acip kapatmak icin:")
            if AnimButton(beklePanelTusu and "Basin..." or getKeyName(seciliKisayol[0]), imgui.ImVec2(150, 30)) then
                beklePanelTusu = true; bekleMouseTusu = false; bekleCruiseTusu = false; bekleSinematikTusu = false; bekleScoreboardTusu = false; bindGecikmesi = os.clock() + 0.2
            end
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Imleci gizlemek icin:")
            if AnimButton(bekleMouseTusu and "Basin..." or getKeyName(seciliMouseKisayol[0]), imgui.ImVec2(150, 30)) then
                bekleMouseTusu = true; beklePanelTusu = false; bekleCruiseTusu = false; bekleSinematikTusu = false; bekleScoreboardTusu = false; bindGecikmesi = os.clock() + 0.2
            end
            imgui.Dummy(imgui.ImVec2(0, 5))
            
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Skor Tablosu (TAB):")
            if AnimButton(bekleScoreboardTusu and "Basin..." or getKeyName(seciliScoreboardKisayol[0]), imgui.ImVec2(150, 30)) then
                bekleScoreboardTusu = true; beklePanelTusu = false; bekleMouseTusu = false; bekleCruiseTusu = false; bekleSinematikTusu = false; bindGecikmesi = os.clock() + 0.2
            end

        elseif seciliSekme[0] == 16 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "PIYASA VE ILAN TAKIP")
            BilgiKutusu("Sohbette sizin belirlediginiz kelimeleri tarar ve ekrana anlik bildirim yansitir.")
            imgui.Dummy(imgui.ImVec2(0, 15))

            imgui.PushItemWidth(250)
            imgui.InputText("Aranacak Kelime", inputPiyasa, 128)
            imgui.PopItemWidth()
            imgui.SameLine()
            if AnimButton("Ekle", imgui.ImVec2(80, 24)) then
                local kStr = ffi.string(inputPiyasa)
                if kStr ~= "" then table.insert(piyasaFiltreleri, kStr); ayarlariKaydet(); ffi.copy(inputPiyasa, "") end
            end

            imgui.Dummy(imgui.ImVec2(0, 10))
            
            imgui.BeginChild("PiyasaSolCol", imgui.ImVec2(280, 0), false)
            imgui.BeginGroup()
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "AKTIF FILTRELER")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if #piyasaFiltreleri == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Henuz filtre eklenmemis.")
            else
                for i, kelime in ipairs(piyasaFiltreleri) do
                    imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.4, 1.0), kelime)
                    imgui.SameLine(imgui.GetWindowContentRegionWidth() - 30)
                    if AnimButton("X##psil"..i, imgui.ImVec2(30, 24)) then table.remove(piyasaFiltreleri, i); ayarlariKaydet() end
                end
            end
            imgui.EndGroup()
            imgui.EndChild()

            imgui.SameLine(0, 15)

            imgui.BeginChild("PiyasaSagCol", imgui.ImVec2(0, 0), false)
            imgui.BeginGroup()
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "YAKALANAN LOGLAR")
            imgui.Separator()
            imgui.Dummy(imgui.ImVec2(0, 5))
            if #piyasaLoglari == 0 then
                imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Henuz bir ilan yakalanmadi.")
            else
                for i, log in ipairs(piyasaLoglari) do
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "[" .. log.zaman .. "]")
                    imgui.SameLine()
                    imgui.TextColored(imgui.ImVec4(0.5, 0.6, 1.0, 1.0), "[Tetikte: " .. log.kelime .. "]")
                    imgui.PushTextWrapPos(imgui.GetWindowWidth() - 15)
                    imgui.TextUnformatted(u8_decode(log.metin))
                    imgui.PopTextWrapPos()
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.GetWindowDrawList():AddLine(imgui.ImVec2(imgui.GetCursorScreenPos().x, imgui.GetCursorScreenPos().y), imgui.ImVec2(imgui.GetCursorScreenPos().x + imgui.GetWindowWidth() - 30, imgui.GetCursorScreenPos().y), imgui.GetColorU32Vec4(imgui.ImVec4(1,1,1,0.03)), 1.0)
                end
            end
            imgui.EndGroup()
            imgui.EndChild()

        elseif seciliSekme[0] == 17 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "MESLEK VERIMLILIK ASISTANI")
            BilgiKutusu("Tirci, Copcu gibi mesleklerde emeginizin ve kârınızın saatlik/anlik bilancosunu cikarir.")
            imgui.Dummy(imgui.ImVec2(0, 15))

            if meslekAktif then
                if AnimButton("Mesaiyi Bitir", imgui.ImVec2(200, 36)) then meslekAktif = false end
            else
                if AnimButton("Mesaiye Basla", imgui.ImVec2(200, 36)) then 
                    meslekAktif = true
                    meslekBaslangic = os.time()
                    if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
                        meslekBaslangicPara = getPlayerMoney(PLAYER_HANDLE)
                    else
                        meslekBaslangicPara = 0
                    end
                    meslekSonPara = meslekBaslangicPara
                    meslekKazanilan = 0
                    meslekTur = 0
                end
            end

            imgui.SameLine(250)
            imgui.PushItemWidth(200)
            imgui.InputInt("Hedef Kazanc ($)", meslekHedefPara, 1000)
            imgui.PopItemWidth()

            imgui.Dummy(imgui.ImVec2(0, 20))
            
            local calisilanSaniye = meslekAktif and (os.time() - meslekBaslangic) or 0
            local mSaat = math.floor(calisilanSaniye / 3600)
            local mDakika = math.floor((calisilanSaniye % 3600) / 60)
            local mSaniye = calisilanSaniye % 60
            local saatlikOrtalama = 0
            if calisilanSaniye > 60 then saatlikOrtalama = math.floor((meslekKazanilan / (calisilanSaniye / 60)) * 60) end

            imgui.Columns(3, "MeslekCol", false)
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "GECEN SURE")
            imgui.Separator()
            if fontComboCount > 0 then imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1]) end
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), string.format("%02d:%02d:%02d", mSaat, mDakika, mSaniye))
            if fontComboCount > 0 then imgui.PopFont() end

            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "NET KAZANC")
            imgui.Separator()
            if fontComboCount > 0 then imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1]) end
            imgui.TextColored(imgui.ImVec4(0.4, 1.0, 0.4, 1.0), "$ " .. formatNumber(meslekKazanilan))
            if fontComboCount > 0 then imgui.PopFont() end

            imgui.NextColumn()
            imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "SAATLIK POTANSIYEL")
            imgui.Separator()
            if fontComboCount > 0 then imgui.PushFont(mevcutFontPointers[seciliFontIndex[0] + 1]) end
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 0.4, 1.0), "$ " .. formatNumber(saatlikOrtalama) .. "/h")
            if fontComboCount > 0 then imgui.PopFont() end
            imgui.Columns(1)

            imgui.Dummy(imgui.ImVec2(0, 25))

            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Teslimat / Tur Sayaci:")
            imgui.SameLine()
            if AnimButton("-1", imgui.ImVec2(40, 30)) and meslekTur > 0 then meslekTur = meslekTur - 1 end
            imgui.SameLine()
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), string.format("   %d Tur   ", meslekTur))
            imgui.SameLine()
            if AnimButton("+1", imgui.ImVec2(40, 30)) then meslekTur = meslekTur + 1 end

            imgui.Dummy(imgui.ImVec2(0, 15))
            imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Hedefe Ulasma Durumu:")
            local hYuzde = math.min(1.0, (meslekKazanilan / math.max(1, meslekHedefPara[0])))
            imgui.PushStyleColor(imgui.Col.PlotHistogram, imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0))
            imgui.ProgressBar(hYuzde, imgui.ImVec2(-1, 25), string.format("%% %d Tamamlandi", math.floor(hYuzde * 100)))
            imgui.PopStyleColor()

        elseif seciliSekme[0] == 18 then
            imgui.TextColored(imgui.ImVec4(1.0, 1.0, 1.0, 1.0), "EKRAN GORUNTUSU GALERISI")
            BilgiKutusu("SAMP tarafindan klasore kaydedilen ekran goruntulerinizi oyun icinden inceler.")
            imgui.Dummy(imgui.ImVec2(0, 15))

            if not lfs_yuklu then
                imgui.TextColored(imgui.ImVec4(1.0, 0.4, 0.4, 1.0), "HATA: Luafilesystem (lfs) kutuphanesi eksik oldugu icin galeri kullanilamaz.")
            else
                if AnimButton("Klasoru Tara / Yenile", imgui.ImVec2(200, 35)) then tazeSSListesi() end
                imgui.SameLine()
                imgui.PushItemWidth(250)
                imgui.InputText("Ara (Tarih/Isim)", aramaGaleri, 128)
                imgui.PopItemWidth()
                imgui.Dummy(imgui.ImVec2(0, 10))
                
                imgui.BeginChild("GaleriSolCol", imgui.ImVec2(300, 420), false)
                imgui.BeginGroup()
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "KAYDEDILEN GORSELLER")
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 5))
                if #ssListesi == 0 then
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "SS bulunamadi.")
                else
                    local gStr = ffi.string(aramaGaleri):lower()
                    for i, dosya in ipairs(ssListesi) do
                        if gStr == "" or dosya:lower():find(gStr) then
                            if imgui.Selectable(dosya, seciliSSIndex[0] == i) then
                                seciliSSIndex[0] = i
                                yuklenenSSIsim = dosya
                                local tamYol = os.getenv("USERPROFILE") .. "\\Documents\\GTA San Andreas User Files\\SAMP\\screens\\" .. dosya
                                yuklenenSSTexture = imgui.CreateTextureFromFile(tamYol)
                            end
                        end
                    end
                end
                imgui.EndGroup()
                imgui.EndChild()
                
                imgui.SameLine(0, 15)
                
                imgui.BeginChild("GaleriSagCol", imgui.ImVec2(0, 420), false)
                imgui.BeginGroup()
                imgui.TextColored(imgui.ImVec4(temaRengi[0], temaRengi[1], temaRengi[2], 1.0), "ONIZLEME: " .. yuklenenSSIsim)
                imgui.Separator()
                imgui.Dummy(imgui.ImVec2(0, 5))
                if yuklenenSSTexture then
                    local pW = imgui.GetWindowContentRegionWidth()
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - pW) / 2)
                    imgui.Image(yuklenenSSTexture, imgui.ImVec2(pW, 310))
                    imgui.Dummy(imgui.ImVec2(0, 5))
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - pW) / 2)
                    if AnimButton("Bu Dosyayi Sil", imgui.ImVec2(pW, 35)) then
                        local silYol = os.getenv("USERPROFILE") .. "\\Documents\\GTA San Andreas User Files\\SAMP\\screens\\" .. yuklenenSSIsim
                        os.remove(silYol)
                        yuklenenSSTexture = nil
                        yuklenenSSIsim = ""
                        seciliSSIndex[0] = -1
                        tazeSSListesi()
                        sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Ekran goruntusu basariyla silindi.", -1)
                    end
                else
                    imgui.TextColored(imgui.ImVec4(0.85, 0.85, 0.85, 1.0), "Gostermek icin soldan bir gorsel secin.")
                end
                imgui.EndGroup()
                imgui.EndChild()
            end
        end
        imgui.EndChild()
        imgui.End()
        imgui.PopStyleVar() 
        if fontAktifState then imgui.PopFont() end
    end
)

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    ayarlariYukle()
    otomatikGuncellemeKontrolu()
    globalDuyuruKontrol()
    
    if sampev_yuklu then sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}KaUI Modern Arayuz Paneli (v" .. SURUM .. ") yuklendi. Komut: /panel", -1) end
    
    sampRegisterChatCommand("panel", function()
        if bootState == 0 then
            bootState = 1
            bootStartTime = os.clock()
            renderWindow[0] = true
        elseif bootState == 3 then
            if animState == 0 or animState == 3 then
                animState = 1
                renderWindow[0] = true
            elseif animState == 2 or animState == 1 then
                animState = 3
            end
        end
        if renderWindow[0] then mouseAktif = true end
    end)
    
    local wasInCar = false
    while true do
        wait(0)
        
        local herhangiOzelTusBekliyor = false
        for i, v in ipairs(ozelButonlar) do
            if v.bekliyor then
                herhangiOzelTusBekliyor = true
                if os.clock() > bindGecikmesi then
                    for kStr, vKey in pairs(vkeys) do
                        if type(kStr) == "string" and kStr:sub(1,3) == "VK_" and wasKeyPressed(vKey) then
                            if vKey == vkeys.VK_ESCAPE then
                                v.bekliyor = false
                                break
                            elseif vKey == vkeys.VK_BACK then
                                v.tus = {}
                                v.bekliyor = false
                                ayarlariKaydet()
                                break
                            elseif vKey == vkeys.VK_CONTROL or vKey == vkeys.VK_LCONTROL or vKey == vkeys.VK_RCONTROL or
                                   vKey == vkeys.VK_MENU or vKey == vkeys.VK_LMENU or vKey == vkeys.VK_RMENU or
                                   vKey == vkeys.VK_SHIFT or vKey == vkeys.VK_LSHIFT or vKey == vkeys.VK_RSHIFT then
                                -- Mod tuşlarını geç
                            else
                                local combo = {}
                                if isKeyDown(vkeys.VK_CONTROL) then table.insert(combo, vkeys.VK_CONTROL) end
                                if isKeyDown(vkeys.VK_MENU) then table.insert(combo, vkeys.VK_MENU) end
                                if isKeyDown(vkeys.VK_SHIFT) then table.insert(combo, vkeys.VK_SHIFT) end
                                table.insert(combo, vKey)
                                v.tus = combo
                                v.bekliyor = false
                                ayarlariKaydet()
                                break
                            end
                        end
                    end
                end
            end
        end

        if not (beklePanelTusu or bekleMouseTusu or bekleCruiseTusu or bekleSinematikTusu or bekleScoreboardTusu or herhangiOzelTusBekliyor) then
            
            for i, v in ipairs(ozelButonlar) do
                if v.tus and type(v.tus) == "table" and #v.tus > 0 then
                    local mainKey = v.tus[#v.tus]
                    if wasKeyPressed(mainKey) and not sampIsChatInputActive() and not sampIsDialogActive() then
                        local allModsDown = true
                        for j = 1, #v.tus - 1 do
                            if not isKeyDown(v.tus[j]) then
                                allModsDown = false
                                break
                            end
                        end
                        if allModsDown then
                            sampSendChat(u8_decode(v.komut))
                        end
                    end
                end
            end
            
            if seciliKisayol[0] ~= 0 and wasKeyPressed(seciliKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                if bootState == 0 then
                    bootState = 1
                    bootStartTime = os.clock()
                    renderWindow[0] = true
                elseif bootState == 3 then
                    if animState == 0 or animState == 3 then
                        animState = 1
                        renderWindow[0] = true
                    elseif animState == 2 or animState == 1 then
                        animState = 3
                    end
                end
                if renderWindow[0] then mouseAktif = true end
            end
            
            if renderWindow[0] and seciliMouseKisayol[0] ~= 0 then
                if wasKeyPressed(seciliMouseKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                    mouseAktif = not mouseAktif
                end
            end

            if seciliSinematikKisayol[0] ~= 0 and wasKeyPressed(seciliSinematikKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                sinematikAktif = not sinematikAktif
                if sinematikAktif then
                    origSensX = ffi.cast("float*", 0xB6EC1C)[0]
                    origSensY = ffi.cast("float*", 0xB6EC18)[0]
                    ffi.cast("float*", 0xB6EC1C)[0] = origSensX * 0.2
                    ffi.cast("float*", 0xB6EC18)[0] = origSensY * 0.2
                    displayHud(false)
                    displayRadar(false)
                    sampSetChatDisplayMode(0) 
                    sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Sinematik Cekim Modu (Puruzsuz Kamera) Aktif Edildi.", -1)
                else
                    ffi.cast("float*", 0xB6EC1C)[0] = origSensX
                    ffi.cast("float*", 0xB6EC18)[0] = origSensY
                    displayHud(true)
                    displayRadar(true)
                    sampSetChatDisplayMode(1) 
                    sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Sinematik Cekim Modu Kapatildi.", -1)
                end
            end
            
            if ozelScoreboardAktif[0] and seciliScoreboardKisayol[0] ~= 0 and wasKeyPressed(seciliScoreboardKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                scoreboardAcik = not scoreboardAcik
            end
        end

        if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
            if meslekAktif then
                local cMoney = getPlayerMoney(PLAYER_HANDLE)
                if meslekSonPara ~= 0 and cMoney > meslekSonPara then meslekKazanilan = meslekKazanilan + (cMoney - meslekSonPara) end
                meslekSonPara = cMoney
            end

            if isCharInAnyCar(PLAYER_PED) then
                local car = storeCarCharIsInNoSave(PLAYER_PED)
                if not wasInCar then 
                    wasInCar = true
                    sesCarsUsed = sesCarsUsed + 1 
                    
                    if otoKemerAktif[0] then 
                        lua_thread.create(function()
                            wait(500) 
                            sampSendChat("/kemer") 
                        end)
                    end
                    if otoMotorAktif[0] then 
                        lua_thread.create(function()
                            wait(1000) 
                            sampSendChat("/motor") 
                        end)
                    end
                end
                
                if not bekleCruiseTusu and not beklePanelTusu and not bekleMouseTusu and not bekleSinematikTusu and not bekleScoreboardTusu then
                    if wasKeyPressed(seciliCruiseKisayol[0]) and not sampIsChatInputActive() and not sampIsDialogActive() then
                        isCruiseActive = not isCruiseActive
                        if isCruiseActive then
                            cruiseSpeed = getCarSpeed(car)
                            sampAddChatMessage("{4A90E2}[Cruise] {FFFFFF}Hiz sabitlendi: " .. math.floor(cruiseSpeed * 3.6) .. " km/h", -1)
                            addOneOffSound(0,0,0, 1145)
                        else
                            sampAddChatMessage("{4A90E2}[Cruise] {FFFFFF}Hiz sabitleyici kapatildi.", -1)
                            addOneOffSound(0,0,0, 1145)
                        end
                    end
                end
                
                if isCruiseActive then
                    if (isKeyDown(vkeys.VK_W) or isKeyDown(vkeys.VK_S) or isKeyDown(vkeys.VK_SPACE)) and not sampIsChatInputActive() and not sampIsDialogActive() then
                        isCruiseActive = false
                        sampAddChatMessage("{FF0000}[Cruise] {FFFFFF}Mudehale edildi, sabitleyici devreden cikti.", -1)
                        addOneOffSound(0,0,0, 1085)
                    else
                        local isTurning = (isKeyDown(vkeys.VK_A) or isKeyDown(vkeys.VK_D) or isKeyDown(vkeys.VK_LEFT) or isKeyDown(vkeys.VK_RIGHT)) and not sampIsChatInputActive() and not sampIsDialogActive()
                        if not isTurning then setCarForwardSpeed(car, cruiseSpeed) end
                    end
                end
                
                local speed = getCarSpeed(car) * 3.6 
                if speed > sesMaxSpeed then sesMaxSpeed = speed end
                if kameraSabitleAktif[0] then ffi.cast("float*", 0xB70118)[0] = 50.0 end
            else
                wasInCar = false
                isCruiseActive = false
            end
        end

        if (beklePanelTusu or bekleMouseTusu or bekleCruiseTusu or bekleSinematikTusu or bekleScoreboardTusu) and os.clock() > bindGecikmesi then
            for k, v in pairs(vkeys) do
                if type(k) == "string" and k:sub(1,3) == "VK_" and wasKeyPressed(v) then
                    if v ~= vkeys.VK_ESCAPE then
                        if beklePanelTusu then seciliKisayol[0] = v end
                        if bekleMouseTusu then seciliMouseKisayol[0] = v end
                        if bekleCruiseTusu then seciliCruiseKisayol[0] = v end
                        if bekleSinematikTusu then seciliSinematikKisayol[0] = v end
                        if bekleScoreboardTusu then seciliScoreboardKisayol[0] = v end
                    end
                    beklePanelTusu, bekleMouseTusu, bekleCruiseTusu, bekleSinematikTusu, bekleScoreboardTusu = false, false, false, false, false
                    ayarlariKaydet()
                    break
                end
            end
        end
        
        if guncellemeSinyali then
            guncellemeSinyali = false 
            lua_thread.create(function()
                wait(1500)
                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Panel icin yeni guncelleme (v" .. guncellemeSurumu .. ") indiriliyor...", -1)
                local tempFile = getWorkingDirectory() .. "\\panel_temp_" .. os.time() .. ".lua"
                downloadUrlToFile(guncellemeLinki, tempFile, function(id2, status2, p12, p22)
                    if status2 == 58 then
                        local yf = io.open(tempFile, "r")
                        if yf then
                            local yeniKod = yf:read("*a")
                            yf:close()
                            local ak = io.open(scriptYolu, "w")
                            if ak then
                                ak:write(yeniKod)
                                ak:close()
                                os.remove(tempFile)
                                sampAddChatMessage("{4A90E2}[Sistem] {FFFFFF}Guncelleme basariyla kuruldu! Panel yeniden baslatiliyor...", -1)
                                thisScript():reload()
                            else
                                sampAddChatMessage("{FF0000}[Hata] {FFFFFF}Dosya bir editor tarafindan kilitlendigi icin yazilamadi.", -1)
                                os.remove(tempFile)
                            end
                        end
                    elseif status2 == 73 or status2 == 6 then
                        sampAddChatMessage("{FF0000}[Hata] {FFFFFF}Baglanti veya adres hatasi, guncelleme indirilemedi.", -1)
                    end
                end)
            end)
        end
        
        local simdi = os.time()
        for i, v in ipairs(otoMesajlar) do
            if v.aktif and simdi >= v.sonraki_zaman then
                sampSendChat(u8_decode(v.komut))
                v.sonraki_zaman = simdi + (v.gun * 86400) + (v.saat * 3600) + (v.dakika * 60) + v.saniye
            end
        end
        
        if sampIsLocalPlayerSpawned() and doesCharExist(PLAYER_PED) then
            if os.clock() - lastNearbyUpdate > 1.0 then
                local tempNames = {}
                local tempIDs = {}
                local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
                for _, ped in ipairs(getAllChars()) do
                    if ped ~= PLAYER_PED then
                        local isPlayer, id = sampGetPlayerIdByCharHandle(ped)
                        if isPlayer then
                            local px, py, pz = getCharCoordinates(ped)
                            if getDistanceBetweenCoords3d(myX, myY, myZ, px, py, pz) <= 15.0 then
                                local name = sampGetPlayerNickname(id):gsub("_", " ")
                                table.insert(tempNames, string.format("[%d] %s", id, name))
                                table.insert(tempIDs, id)
                            end
                        end
                    end
                end
                currentNearbyNames = tempNames
                currentNearbyIDs = tempIDs
                if #tempNames > 0 then
                    nearbyComboItems = ffi.new('const char*[?]', #tempNames)
                    nearbyPointers = {}
                    for i, v in ipairs(tempNames) do
                        nearbyPointers[i] = imgui.new.char[256](v)
                        nearbyComboItems[i-1] = nearbyPointers[i]
                    end
                else
                    nearbyComboItems = ffi.new('const char*[1]')
                    nearbyPointers = { imgui.new.char[256]("Yakinda oyuncu bulunamadi") }
                    nearbyComboItems[0] = nearbyPointers[1]
                end
                if seciliChatTarget[0] >= #tempNames and #tempNames > 0 then seciliChatTarget[0] = #tempNames - 1 elseif #tempNames == 0 then seciliChatTarget[0] = 0 end
                lastNearbyUpdate = os.clock()
            end
            
            local cPx, cPy, cPz = getCharCoordinates(PLAYER_PED)
            if cPx ~= 0.0 and sesLastPx ~= 0.0 then
                local pDist = getDistanceBetweenCoords3d(cPx, cPy, cPz, sesLastPx, sesLastPy, sesLastPz)
                if pDist > 0.1 and pDist < 100.0 then
                    sesLastActive = os.clock()
                    if isCharInAnyCar(PLAYER_PED) then sesCarDist = sesCarDist + pDist else sesFootDist = sesFootDist + pDist end
                end
            end
            sesLastPx, sesLastPy, sesLastPz = cPx, cPy, cPz
            
            if os.clock() - sesLastActive > 60.0 then sesAfkTime = sesAfkTime + 1; wait(1000) end
            
            local cMoney = getPlayerMoney(PLAYER_HANDLE)
            if sesLastMoney ~= 0 then
                if cMoney > sesLastMoney then sesMoneyEarned = sesMoneyEarned + (cMoney - sesLastMoney) elseif cMoney < sesLastMoney then sesMoneyLost = sesMoneyLost + (sesLastMoney - cMoney) end
            end
            sesLastMoney = cMoney
            
            for _, ped in ipairs(getAllChars()) do
                if ped ~= PLAYER_PED then
                    local isP, pId = sampGetPlayerIdByCharHandle(ped)
                    if isP then
                        local dist = getDistanceBetweenCoords3d(cPx, cPy, cPz, getCharCoordinates(ped))
                        if dist <= 15.0 then
                            local nName = sampGetPlayerNickname(pId):gsub("_", " ")
                            if not sesPlayersSeen[nName] then sesPlayersSeen[nName] = true end
                            if favoritePlayers[nName] then
                                local t = os.clock()
                                if t > (favoriteAlerted[nName] or 0) then
                                    sampAddChatMessage("{FFD700}[Favori Radari] {FFFFFF}" .. nName .. " yakininizda!", -1)
                                    addOneOffSound(0, 0, 0, 1150)
                                    favoriteAlerted[nName] = t + 300.0 
                                end
                            end
                        end
                    end
                end
            end
        end

        if g_SabitZaman then setTimeOfDay(g_SabitZaman, 0) end
    end
end
