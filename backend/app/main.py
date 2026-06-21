from contextlib import asynccontextmanager
import logging
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.admin_panel_ui import mount_admin_panel
from app.middleware import RedisRateLimitMiddleware
from app.middleware_security_headers import SecurityHeadersMiddleware
from app.routers.admin import router as admin_router
from app.routers.auth import router as auth_router
from app.routers.categories import router as categories_router
from app.routers.kyc import router as kyc_router
from app.routers.listings import router as listings_router
from app.routers.messages import router as messages_router
from app.routers.orders import router as orders_router
from app.routers.favorites import router as favorites_router
from app.routers.cart import router as cart_router
from app.routers.reports import router as reports_router
from app.routers.reviews import router as reviews_router
from app.routers.notifications import router as notifications_router
from app.routers.support import router as support_router
from app.routers.users import router as users_router
from app.routers.webhooks import router as webhooks_router
from app.routers.ws import router as ws_router
from app.settings import settings
from app.startup import init_database


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_database()
    yield


def create_app() -> FastAPI:
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(RedisRateLimitMiddleware)

    cors_kwargs: dict = {
        "allow_credentials": True,
        "allow_methods": ["*"],
        "allow_headers": ["*"],
        "expose_headers": ["*"],
    }
    origins = settings.cors_origin_list()
    if origins:
        cors_kwargs["allow_origins"] = origins
    if settings.cors_origin_regex:
        cors_kwargs["allow_origin_regex"] = settings.cors_origin_regex
    elif not origins:
        cors_kwargs["allow_origin_regex"] = (
            r"https?://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+"
            r"|172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+)(:\d+)?"
        )
    app.add_middleware(CORSMiddleware, **cors_kwargs)

    @app.exception_handler(Exception)
    async def _unhandled_exception(_request: Request, exc: Exception) -> JSONResponse:
        """Évite les 500 sans corps JSON (le navigateur affiche alors une erreur CORS trompeuse)."""
        return JSONResponse(status_code=500, content={"detail": str(exc)})

    if settings.sentry_dsn:
        from app.sentry_init import init_sentry

        init_sentry()

    app.include_router(auth_router, prefix=settings.api_prefix)
    app.include_router(categories_router, prefix=settings.api_prefix)
    app.include_router(listings_router, prefix=settings.api_prefix)
    app.include_router(messages_router, prefix=settings.api_prefix)
    app.include_router(orders_router, prefix=settings.api_prefix)
    app.include_router(kyc_router, prefix=settings.api_prefix)
    app.include_router(reports_router, prefix=settings.api_prefix)
    app.include_router(reviews_router, prefix=settings.api_prefix)
    app.include_router(favorites_router, prefix=settings.api_prefix)
    app.include_router(cart_router, prefix=settings.api_prefix)
    app.include_router(notifications_router, prefix=settings.api_prefix)
    app.include_router(users_router, prefix=settings.api_prefix)
    app.include_router(support_router, prefix=settings.api_prefix)
    app.include_router(admin_router, prefix=settings.api_prefix)
    app.include_router(webhooks_router, prefix=settings.api_prefix)
    app.include_router(ws_router)
    mount_admin_panel(app)

    uploads_dir = Path(__file__).resolve().parent.parent / "uploads"
    uploads_dir.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

    @app.get("/", response_class=HTMLResponse)
    def root() -> str:
        return """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>SombaTeka - 100% Congolais</title>
            <script src="https://cdn.tailwindcss.com"></script>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
            <style>
                @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;900&display=swap');
                body { font-family: 'Inter', sans-serif; background-color: #000; overflow: hidden; }
                .mobile-container { max-width: 420px; margin: 0 auto; height: 100vh; background: #f8f9fa; position: relative; overflow: hidden; display: flex; flex-direction: column; }
                .screen { display: none; height: 100%; flex-direction: column; overflow-y: auto; padding-bottom: 80px; background: white; opacity: 0; transition: opacity 0.3s ease; }
                .screen.active { display: flex; opacity: 1; }
                
                .st-gradient { background: #1a73e8; }
                .product-card { background: white; border-radius: 20px; overflow: hidden; transition: all 0.2s; border: 1px solid #eee; }
                .btn-primary { background: #1a73e8; color: white; border-radius: 16px; padding: 16px; font-weight: 700; transition: all 0.2s; width: 100%; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 8px 20px rgba(26, 115, 232, 0.3); }
                .btn-primary:active { transform: scale(0.98); opacity: 0.9; }
                
                .modal { display: none; position: absolute; inset: 0; background: rgba(0,0,0,0.6); z-index: 100; backdrop-filter: blur(4px); }
                .modal-content { background: white; margin-top: auto; border-radius: 30px 30px 0 0; padding: 24px; animation: slideUp 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); max-height: 90vh; overflow-y: auto; }
                
                /* Dots */
                .ob-dot { transition: all 0.3s ease; }
                .ob-dot.active { width: 32px; background: #1a73e8; border-radius: 10px; }
                
                /* Input styles */
                .input-field { background: #f4f6f8; border-radius: 18px; padding: 18px; display: flex; align-items: center; gap: 12px; transition: all 0.2s; border: 2px solid transparent; }
                .input-field:focus-within { background: white; border-color: #1a73e8; box-shadow: 0 0 0 4px rgba(26, 115, 232, 0.1); }
                
                .st-toast { position: absolute; top: 20px; left: 20px; right: 20px; background: white; border-radius: 20px; padding: 16px; display: flex; align-items: center; gap: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.1); z-index: 200; transform: translateY(-150px); transition: transform 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); border: 1px solid #eee; }
                .st-toast.active { transform: translateY(0); }
                .st-toast-icon { width: 40px; height: 40px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 18px; }
                .st-toast-error { background: #fee2e2; color: #ef4444; }
                .st-toast-success { background: #dcfce7; color: #22c55e; }
                
                .no-scrollbar::-webkit-scrollbar { display: none; }
                .animate-in { animation: fadeIn 0.4s ease-out; }
                @keyframes fadeIn { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
            </style>
            <script>
                // GLOBAL STATE
                let currentUser = null;
                let currentListings = [];
                let currentCategories = [];
                let currentMessages = [];
                let onboardingStep = 0;

                // Helper to get auth headers
                const getHeaders = () => ({
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${localStorage.getItem('token')}`
                });

                // CUSTOM ALERT SYSTEM
                window.showAlert = function(msg, type = 'error') {
                    const toast = document.getElementById('st-toast');
                    const icon = document.getElementById('st-toast-icon');
                    const text = document.getElementById('st-toast-text');
                    
                    // Fix: Handle object errors from backend
                    let displayMsg = msg;
                    if (typeof msg === 'object' && msg !== null) {
                        displayMsg = msg.detail || JSON.stringify(msg);
                    }
                    
                    text.innerText = displayMsg;
                    icon.className = `st-toast-icon ${type === 'error' ? 'st-toast-error' : 'st-toast-success'}`;
                    icon.innerHTML = `<i class="fas ${type === 'error' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>`;
                    
                    toast.classList.add('active');
                    setTimeout(() => toast.classList.remove('active'), 3000);
                }

                async function showScreen(id) {
                    // Update visibility
                    document.querySelectorAll('.screen').forEach(s => {
                        s.classList.remove('active');
                        s.style.display = 'none';
                    });
                    const target = document.getElementById('screen-' + id);
                    if (target) {
                        target.style.display = 'flex';
                        setTimeout(() => target.classList.add('active'), 10);
                        target.scrollTo(0, 0);
                    }

                    // Bottom Nav visibility & highlighting
                    const nav = document.getElementById('bottom-nav');
                    if (!nav) return;
                    
                    const hideNavOn = ['login', 'onboarding-1', 'onboarding-2', 'onboarding-3'];
                    if (hideNavOn.includes(id)) {
                        nav.classList.add('hidden');
                    } else {
                        nav.classList.remove('hidden');
                        
                        // Reset all nav icons
                        document.querySelectorAll('#bottom-nav button i').forEach(i => i.className = i.className.replace('text-blue-600', 'text-gray-400'));
                        document.querySelectorAll('#bottom-nav button span').forEach(s => s.className = s.className.replace('text-blue-600', 'text-gray-400'));
                        
                        // Highlight active button if it exists in nav
                        const activeBtn = document.querySelector(`#bottom-nav button[onclick*="${id}"]`);
                        if (activeBtn) {
                            const icon = activeBtn.querySelector('i');
                            const span = activeBtn.querySelector('span');
                            if (icon) icon.className = icon.className.replace('text-gray-400', 'text-blue-600');
                            if (span) span.className = span.className.replace('text-gray-400', 'text-blue-600');
                        }
                    }

                    // Screen specific logic
                    if (id !== 'chat-view') activeRecipientId = null;
                    if (id === 'messages-list') await fetchMessages();
                    if (id === 'profile') renderProfile();
                }
                window.showScreen = showScreen;

                function renderProfile() {
                    if (!currentUser) return;
                    document.getElementById('profile-name').innerText = currentUser.official_name || "Utilisateur SombaTeka";
                    document.getElementById('profile-phone').innerText = currentUser.phone_e164;
                    document.getElementById('profile-badge').style.display = currentUser.is_verified_seller ? 'inline-block' : 'none';
                }

                // Polling for new messages
                setInterval(async () => {
                    const token = localStorage.getItem('token');
                    if (!token) return;
                    
                    const activeScreen = document.querySelector('.screen.active');
                    if (activeScreen && (activeScreen.id === 'screen-messages-list' || activeScreen.id === 'screen-chat-view')) {
                        const oldLen = currentMessages.length;
                        await fetchMessages();
                        if (currentMessages.length > oldLen) {
                            if (activeScreen.id === 'screen-messages-list') renderMessagesList();
                            if (activeScreen.id === 'screen-chat-view' && activeRecipientId) updateChatMessages();
                        }
                    }
                }, 5000);

                async function fetchMessages() {
                    try {
                        const res = await fetch('/api/messages/', { headers: getHeaders() });
                        if (res.ok) {
                            currentMessages = await res.json();
                            renderMessagesList();
                        }
                    } catch (e) { console.error("Error fetching messages:", e); }
                }

                function renderMessagesList() {
                    const list = document.getElementById('messages-list-container');
                    if (!list) return;
                    
                    if (currentMessages.length === 0) {
                        list.innerHTML = `
                            <div class="flex flex-col items-center justify-center p-12 text-center">
                                <div class="w-20 h-20 bg-gray-50 rounded-[40px] flex items-center justify-center text-gray-200 mb-6">
                                    <i class="fas fa-comment-dots text-4xl"></i>
                                </div>
                                <h3 class="text-xl font-black text-gray-900 mb-2">Pas encore de messages</h3>
                                <p class="text-gray-400 text-sm">Vos conversations avec les vendeurs s'afficheront ici.</p>
                            </div>
                        `;
                        return;
                    }

                    const convs = {};
                    currentMessages.forEach(m => {
                        const otherId = m.sender_id === currentUser.id ? m.recipient_id : m.sender_id;
                        if (!convs[otherId] || new Date(m.created_at) > new Date(convs[otherId].lastMessage.created_at)) {
                            convs[otherId] = {
                                lastMessage: m,
                                unreadCount: (m.recipient_id === currentUser.id && !m.is_read) ? 1 : 0
                            };
                        } else if (m.recipient_id === currentUser.id && !m.is_read) {
                            convs[otherId].unreadCount++;
                        }
                    });

                    list.innerHTML = '';
                    const sortedConvs = Object.keys(convs).sort((a, b) => 
                        new Date(convs[b].lastMessage.created_at) - new Date(convs[a].lastMessage.created_at)
                    );

                    sortedConvs.forEach(otherId => {
                        const conv = convs[otherId];
                        const last = conv.lastMessage;
                        const date = new Date(last.created_at);
                        const now = new Date();
                        let timeStr;
                        if (date.toDateString() === now.toDateString()) {
                            timeStr = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                        } else {
                            timeStr = date.toLocaleDateString([], { day: 'numeric', month: 'short' });
                        }
                        const name = `Utilisateur ${otherId}`;
                        
                        list.innerHTML += `
                            <div class="p-4 flex gap-4 cursor-pointer hover:bg-gray-50 transition-all border-b border-gray-50 active:bg-gray-100" onclick="renderChat(${otherId}, '${name}')">
                                <div class="w-14 h-14 bg-blue-50 rounded-2xl flex items-center justify-center text-blue-600 font-black text-xl relative shrink-0 border border-blue-100 shadow-sm">
                                    ${name.charAt(0)}
                                    ${conv.unreadCount > 0 ? `<span class="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-[10px] rounded-full flex items-center justify-center border-2 border-white font-black">${conv.unreadCount}</span>` : ''}
                                </div>
                                <div class="flex-1 min-w-0 flex flex-col justify-center">
                                    <div class="flex justify-between items-center mb-0.5">
                                        <h4 class="font-black text-gray-900 truncate text-sm">${name}</h4>
                                        <span class="text-[10px] ${conv.unreadCount > 0 ? 'text-blue-600 font-black' : 'text-gray-400 font-bold'}">${timeStr}</span>
                                    </div>
                                    <p class="text-xs ${conv.unreadCount > 0 ? 'text-gray-900 font-bold' : 'text-gray-500'} truncate leading-tight">
                                        ${last.sender_id === currentUser.id ? '<span class="text-blue-400 font-bold">Vous:</span> ' : ''}${last.content}
                                    </p>
                                </div>
                            </div>
                        `;
                    });
                }

                const onboardingData = [
                    {
                        title: "Vendez en un clic",
                        desc: "Prenez une photo, fixez un prix et publiez. C'est aussi simple que ça sur SombaTeka.",
                        img: "https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800&q=80"
                    },
                    {
                        title: "Paiements Sécurisés",
                        desc: "Achetez en toute confiance avec notre système de paiement intégré et protégé.",
                        img: "https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=800&q=80"
                    },
                    {
                        title: "Location Sans Stress",
                        desc: "Trouvez votre futur chez-vous. Appartements, villas et bureaux partout au Congo en un clic.",
                        img: "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800&q=80"
                    }
                ];

                function updateOnboardingUI() {
                    const step = onboardingData[onboardingStep];
                    const container = document.querySelector('#screen-onboarding .animate-in');
                    
                    // Add fade out
                    container.style.opacity = '0';
                    container.style.transform = 'translateY(10px)';
                    
                    setTimeout(() => {
                        document.getElementById('ob-title').innerText = step.title;
                        document.getElementById('ob-desc').innerText = step.desc;
                        document.getElementById('ob-image').src = step.img;
                        
                        // Update dots
                        const dots = document.querySelectorAll('.ob-dot');
                        dots.forEach((dot, idx) => {
                            dot.classList.toggle('active', idx === onboardingStep);
                        });
                        
                        // Fade in
                        container.style.opacity = '1';
                        container.style.transform = 'translateY(0)';
                    }, 200);
                }

                window.nextOnboarding = function() {
                    if (onboardingStep < onboardingData.length - 1) {
                        onboardingStep++;
                        updateOnboardingUI();
                    } else {
                        showScreen('login');
                    }
                }

                async function login() {
                    const btn = document.getElementById('login-btn');
                    const phoneInput = document.getElementById('login-phone');
                    let phone = phoneInput.value.trim();
                    
                    if (!phone || phone === "+243") { 
                        showAlert("Veuillez entrer votre numéro de téléphone"); 
                        return; 
                    }
                    
                    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
                    btn.disabled = true;
                    
                    try {
                        const res = await fetch('/api/auth/dev/login', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ phone_e164: phone, password: 'developer' })
                        });
                        
                        const data = await res.json();
                        if (res.ok && data.access_token) {
                            localStorage.setItem('token', data.access_token);
                            await fetchMe();
                            showAlert("Connexion réussie !", "success");
                            await fetchCategories();
                            await renderFeed();
                            setTimeout(() => showScreen('feed'), 500);
                        } else {
                            showAlert(data.detail || "Erreur de connexion");
                        }
                    } catch (e) {
                        showAlert("Erreur de connexion au serveur");
                    } finally {
                        btn.innerHTML = '<span class="text-lg">Continuer</span><i class="fas fa-arrow-right"></i>';
                        btn.disabled = false;
                    }
                }
                window.login = login;

                async function fetchMe() {
                    try {
                        const res = await fetch('/api/auth/me', { headers: getHeaders() });
                        if (res.ok) {
                            const data = await res.json();
                            currentUser = data.user;
                        }
                    } catch (e) { console.error("Error fetching me:", e); }
                }

                async function fetchCategories() {
                    try {
                        const res = await fetch('/api/categories');
                        const data = await res.json();
                        currentCategories = data.items || [];
                        const bar = document.getElementById('category-bar');
                        bar.innerHTML = '<div onclick="renderFeed()" class="px-6 py-2.5 bg-blue-600 text-white rounded-2xl text-xs font-black shadow-lg shadow-blue-200 cursor-pointer whitespace-nowrap">Tout</div>';
                        currentCategories.forEach(c => {
                            bar.innerHTML += `<div onclick="renderFeed('${c.id}')" class="px-6 py-2.5 bg-white text-gray-500 rounded-2xl text-xs font-black border border-gray-100 cursor-pointer hover:bg-gray-50 transition-colors whitespace-nowrap">${c.name}</div>`;
                        });
                    } catch (e) { console.error(e); }
                }

                async function renderFeed(catId = null) {
                    const grid = document.getElementById('feed-grid');
                    grid.innerHTML = '<div class="col-span-2 text-center py-10"><i class="fas fa-spinner fa-spin text-blue-500 text-2xl"></i></div>';
                    try {
                        let url = '/api/listings';
                        if (catId) url += `?category_id=${catId}`;
                        const res = await fetch(url);
                        const data = await res.json();
                        currentListings = data.items || [];
                        grid.innerHTML = '';
                        
                        if (currentListings.length === 0) {
                            grid.innerHTML = '<div class="col-span-2 text-center py-10 text-gray-400 font-bold">Aucun article trouvé</div>';
                        }

                        currentListings.forEach(item => {
                            const isOfficial = item.price_cdf < 5000; 
                            const isRent = item.listing_type === 'rent';
                            grid.innerHTML += `
                                <div class="product-card animate-in shadow-sm hover:shadow-xl transition-all group cursor-pointer" onclick="showDetail(${item.id})">
                                    <div class="relative aspect-[4/5] overflow-hidden bg-gray-100">
                                        <img src="https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500&q=80" class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500">
                                        ${isOfficial ? '<div class="absolute top-3 left-3 bg-blue-600 text-[8px] font-black text-white px-2 py-1 rounded-lg shadow-lg">OFFICIEL</div>' : ''}
                                        ${isRent ? '<div class="absolute top-3 right-3 bg-orange-500 text-[8px] font-black text-white px-2 py-1 rounded-lg shadow-lg">LOCATION</div>' : ''}
                                        <div class="absolute bottom-3 right-3 w-8 h-8 bg-white/80 backdrop-blur rounded-full flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors">
                                            <i class="fas fa-heart text-xs"></i>
                                        </div>
                                    </div>
                                    <div class="p-4">
                                        <h3 class="font-black text-gray-900 text-sm leading-tight mb-2 line-clamp-2">${item.title}</h3>
                                        <div class="flex items-center gap-1">
                                            <span class="text-blue-600 font-black text-lg">${item.price_cdf}$</span>
                                            ${isOfficial ? '<i class="fas fa-check-circle text-blue-400 text-[10px]"></i>' : ''}
                                        </div>
                                        <p class="text-[10px] text-gray-400 mt-1"><i class="fas fa-location-dot mr-1"></i>${item.city || 'Kinshasa'}</p>
                                    </div>
                                </div>
                            `;
                        });
                    } catch (e) {
                        grid.innerHTML = '<div class="col-span-2 text-center py-10 text-red-500">Erreur de chargement</div>';
                    }
                }
                window.renderFeed = renderFeed;

                function showDetail(id) {
                    const p = currentListings.find(x => x.id === id);
                    if (!p) return;
                    document.getElementById('detail-title').innerText = p.title;
                    document.getElementById('detail-price').innerText = p.price_cdf + '$';
                    document.getElementById('detail-desc').innerText = p.description || "Aucune description fournie.";
                    
                    const isOfficial = p.price_cdf < 5000;
                    const contactBtn = document.getElementById('contact-btn');
                    if (isOfficial) {
                        contactBtn.onclick = () => showAlert('Chat indisponible avant achat pour ce compte officiel (Règle Wildberries)');
                    } else {
                        contactBtn.onclick = () => {
                            renderChat(p.seller_id, 'Vendeur');
                        };
                    }
                    showScreen('detail');
                }
                window.showDetail = showDetail;

                let activeRecipientId = null;

                async function renderChat(recipientId, name) {
                    activeRecipientId = recipientId;
                    
                    // Mark as read
                    try {
                        await fetch(`/api/messages/read-all/${recipientId}`, {
                            method: 'POST',
                            headers: getHeaders()
                        });
                        // Update local state for unread counts
                        currentMessages.forEach(m => {
                            if (m.sender_id === recipientId && m.recipient_id === currentUser.id) m.is_read = true;
                        });
                    } catch (e) { console.error("Error marking as read:", e); }

                    const container = document.getElementById('chat-view-container');
                    container.innerHTML = `
                        <div class="flex flex-col h-full bg-white animate-in">
                            <header class="p-4 border-b border-gray-100 flex items-center gap-4 bg-white/80 backdrop-blur-md sticky top-0 z-10">
                                <button onclick="showScreen('messages-list')" class="w-10 h-10 flex items-center justify-center text-gray-400 hover:bg-gray-50 rounded-full transition-colors active:scale-90"><i class="fas fa-chevron-left"></i></button>
                                <div class="w-10 h-10 bg-blue-50 rounded-2xl flex items-center justify-center text-blue-600 font-black border border-blue-100 shadow-sm">
                                    ${name.charAt(0)}
                                </div>
                                <div class="flex-1">
                                    <h2 class="text-sm font-black text-gray-900">${name}</h2>
                                    <p class="text-[9px] text-green-500 font-black uppercase tracking-widest flex items-center gap-1.5">
                                        <span class="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(34,197,94,0.6)]"></span> En ligne
                                    </p>
                                </div>
                                <button class="w-10 h-10 flex items-center justify-center text-gray-400 hover:bg-gray-50 rounded-full"><i class="fas fa-ellipsis-v"></i></button>
                            </header>
                            <div id="chat-messages-scroller" class="flex-1 overflow-y-auto p-4 space-y-6 bg-gray-50/30 no-scrollbar">
                                <div id="chat-messages-container" class="space-y-6"></div>
                            </div>
                            <div class="p-4 bg-white border-t border-gray-100 pb-6">
                                <div class="flex items-center gap-3 bg-gray-100 rounded-2xl p-1.5 pl-4 focus-within:bg-white focus-within:ring-2 focus-within:ring-blue-100 transition-all shadow-inner">
                                    <input type="text" id="chat-input" placeholder="Ecrire un message..." class="flex-1 bg-transparent py-2.5 text-sm outline-none font-medium text-gray-700" onkeypress="if(event.key==='Enter') sendMessage()">
                                    <button onclick="sendMessage()" class="w-11 h-11 st-gradient rounded-xl text-white flex items-center justify-center shadow-lg shadow-blue-200 transition-all active:scale-90 hover:brightness-110">
                                        <i class="fas fa-paper-plane text-sm"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    `;
                    
                    showScreen('chat-view');
                    updateChatMessages();
                }

                function updateChatMessages() {
                    const container = document.getElementById('chat-messages-container');
                    if (!container) return;

                    const messages = currentMessages.filter(m => 
                        (m.sender_id === currentUser.id && m.recipient_id === activeRecipientId) ||
                        (m.sender_id === activeRecipientId && m.recipient_id === currentUser.id)
                    ).sort((a, b) => new Date(a.created_at) - new Date(b.created_at));

                    container.innerHTML = '';
                    let lastDate = null;

                    messages.forEach(m => {
                        const isMe = m.sender_id === currentUser.id;
                        const date = new Date(m.created_at);
                        const dateStr = date.toLocaleDateString([], { day: 'numeric', month: 'long' });
                        const timeStr = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                        
                        if (dateStr !== lastDate) {
                            container.innerHTML += `
                                <div class="flex justify-center my-4">
                                    <span class="bg-gray-200/50 text-gray-500 text-[9px] font-black px-3 py-1 rounded-full uppercase tracking-widest">${dateStr}</span>
                                </div>
                            `;
                            lastDate = dateStr;
                        }

                        container.innerHTML += `
                            <div class="flex flex-col ${isMe ? 'items-end' : 'items-start'} gap-1.5">
                                <div class="${isMe ? 'bg-blue-600 text-white rounded-2xl rounded-tr-none shadow-md shadow-blue-100' : 'bg-white text-gray-800 border border-gray-100 rounded-2xl rounded-tl-none shadow-sm'} px-4 py-3 max-w-[85%] text-[13px] leading-relaxed animate-in">
                                    ${m.content}
                                </div>
                                <div class="flex items-center gap-1.5 px-1">
                                    <span class="text-[9px] text-gray-400 font-bold">${timeStr}</span>
                                    ${isMe ? `<i class="fas fa-check-double text-[9px] ${m.is_read ? 'text-blue-500' : 'text-gray-300'}"></i>` : ''}
                                </div>
                            </div>
                        `;
                    });

                    const scroller = document.getElementById('chat-messages-scroller');
                    if (scroller) {
                        setTimeout(() => {
                            scroller.scrollTo({
                                top: scroller.scrollHeight,
                                behavior: 'smooth'
                            });
                        }, 50);
                    }
                }

                async function sendMessage() {
                    const input = document.getElementById('chat-input');
                    const content = input.value.trim();
                    if (!content || !activeRecipientId) return;

                    input.value = '';
                    try {
                        const res = await fetch('/api/messages/', {
                            method: 'POST',
                            headers: getHeaders(),
                            body: JSON.stringify({
                                recipient_id: activeRecipientId,
                                content: content
                            })
                        });

                        if (res.ok) {
                            const newMsg = await res.json();
                            currentMessages.push(newMsg);
                            updateChatMessages();
                        } else {
                            const err = await res.json();
                            showAlert(err.detail || "Erreur d'envoi");
                        }
                    } catch (e) { showAlert("Erreur réseau"); }
                }
                window.sendMessage = sendMessage;

                window.simulateImageSearch = function() {
                    showAlert("Analyse de l'image (IA style Wildberries)...", "success");
                    setTimeout(() => {
                        showAlert("Résultats trouvés !", "success");
                        renderFeed();
                    }, 2000);
                }

                window.publishItem = () => {
                    showAlert("Publication réussie !", "success");
                    showScreen('feed');
                }

                window.showFilters = () => document.getElementById('filter-modal').style.display = 'flex';
                window.closeFilters = () => document.getElementById('filter-modal').style.display = 'none';
                window.showTOS = () => document.getElementById('tos-modal').style.display = 'flex';
                window.closeTOS = () => document.getElementById('tos-modal').style.display = 'none';
            </script>
        </head>
        <body>
            <div class="mobile-container shadow-2xl">
                <!-- ST TOAST -->
                <div id="st-toast" class="st-toast">
                    <div id="st-toast-icon" class="st-toast-icon"></div>
                    <div><p id="st-toast-text" class="text-sm font-bold text-gray-900"></p></div>
                </div>

                <!-- SCREEN: ONBOARDING 1 -->
                <div id="screen-onboarding-1" class="screen active p-8 bg-white flex flex-col justify-between">
                    <div class="flex justify-end"><button onclick="showScreen('login')" class="text-gray-400 font-bold text-sm">Passer</button></div>
                    <div class="text-center animate-in">
                        <div class="relative w-full aspect-[4/3] mb-12 overflow-hidden rounded-[40px] shadow-2xl shadow-blue-50">
                            <img src="https://images.unsplash.com/photo-1556742044-3c52d6e88c62?w=800&q=80" class="w-full h-full object-cover">
                        </div>
                        <h1 class="text-[32px] font-black text-gray-900 mb-4 leading-tight">Vendez en un clic</h1>
                        <p class="text-gray-500 font-medium leading-relaxed px-4 text-base">Prenez une photo, fixez un prix et publiez. C'est aussi simple que ça sur SombaTeka.</p>
                    </div>
                    <div class="space-y-10">
                        <div class="flex justify-center gap-2.5">
                            <div class="w-8 h-2.5 bg-blue-600 rounded-full"></div>
                            <div class="w-2.5 h-2.5 bg-gray-200 rounded-full"></div>
                            <div class="w-2.5 h-2.5 bg-gray-200 rounded-full"></div>
                        </div>
                        <button onclick="showScreen('onboarding-2')" class="btn-primary py-5">
                            <span>Continuer</span>
                            <i class="fas fa-arrow-right ml-1"></i>
                        </button>
                    </div>
                </div>

                <!-- SCREEN: ONBOARDING 2 -->
                <div id="screen-onboarding-2" class="screen p-8 bg-white flex flex-col justify-between">
                    <div class="flex justify-end"><button onclick="showScreen('login')" class="text-gray-400 font-bold text-sm">Passer</button></div>
                    <div class="text-center animate-in">
                        <div class="relative w-full aspect-[4/3] mb-12 overflow-hidden rounded-[40px] shadow-2xl shadow-blue-50">
                            <img src="https://images.unsplash.com/photo-1563013544-824ae1b704d3?w=800&q=80" class="w-full h-full object-cover">
                        </div>
                        <h1 class="text-[32px] font-black text-gray-900 mb-4 leading-tight">Paiements Sécurisés</h1>
                        <p class="text-gray-500 font-medium leading-relaxed px-4 text-base">Achetez en toute confiance avec notre système de paiement intégré et protégé.</p>
                    </div>
                    <div class="space-y-10">
                        <div class="flex justify-center gap-2.5">
                            <div class="w-2.5 h-2.5 bg-gray-200 rounded-full"></div>
                            <div class="w-8 h-2.5 bg-blue-600 rounded-full"></div>
                            <div class="w-2.5 h-2.5 bg-gray-200 rounded-full"></div>
                        </div>
                        <button onclick="showScreen('onboarding-3')" class="btn-primary py-5">
                            <span>Continuer</span>
                            <i class="fas fa-arrow-right ml-1"></i>
                        </button>
                    </div>
                </div>

                <!-- SCREEN: ONBOARDING 3 -->
                <div id="screen-onboarding-3" class="screen p-8 bg-white flex flex-col justify-between">
                    <div class="flex justify-end"><button onclick="showScreen('login')" class="text-gray-400 font-bold text-sm">Passer</button></div>
                    <div class="text-center animate-in">
                        <div class="relative w-full aspect-[4/3] mb-12 overflow-hidden rounded-[40px] shadow-2xl shadow-blue-50">
                            <img src="https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800&q=80" class="w-full h-full object-cover">
                        </div>
                        <h1 class="text-[32px] font-black text-gray-900 mb-4 leading-tight">Location Sans Stress</h1>
                        <p class="text-gray-500 font-medium leading-relaxed px-4 text-base">Trouvez votre futur chez-vous. Appartements, villas et bureaux partout au Congo en un clic.</p>
                    </div>
                    <div class="space-y-10">
                        <div class="flex justify-center gap-2.5">
                            <div class="w-2.5 h-2.5 bg-gray-200 rounded-full"></div>
                            <div class="w-2.5 h-2.5 bg-gray-200 rounded-full"></div>
                            <div class="w-8 h-2.5 bg-blue-600 rounded-full"></div>
                        </div>
                        <button onclick="showScreen('login')" class="btn-primary py-5">
                            <span>Commencer</span>
                            <i class="fas fa-arrow-right ml-1"></i>
                        </button>
                    </div>
                </div>

                <!-- SCREEN: LOGIN -->
                <div id="screen-login" class="screen p-8 bg-white flex flex-col justify-center">
                    <div class="text-center mb-12 animate-in">
                        <div class="w-20 h-20 st-gradient rounded-[28px] mx-auto flex items-center justify-center text-white text-4xl mb-8 shadow-xl shadow-blue-100">
                            <i class="fas fa-store"></i>
                        </div>
                        <h1 class="text-[32px] font-black text-gray-900 mb-2">Connexion</h1>
                        <p class="text-gray-400 font-medium">Utilisez +243000000000 pour tester</p>
                    </div>
                    <div class="space-y-6 animate-in" style="animation-delay: 0.1s">
                        <div class="input-field">
                            <span class="text-gray-400 font-black text-lg">+243</span>
                            <input id="login-phone" type="tel" value="000000000" class="bg-transparent flex-1 outline-none text-xl font-black text-gray-900 tracking-wider">
                        </div>
                        <button id="login-btn" onclick="login()" class="btn-primary py-5">
                            <span>Continuer</span>
                            <i class="fas fa-arrow-right ml-1"></i>
                        </button>
                        <p class="text-[11px] text-gray-400 text-center px-4 leading-relaxed">
                            En continuant, vous acceptez nos <a href="#" onclick="showTOS()" class="text-blue-500 font-bold underline decoration-2 underline-offset-4">Conditions d'Utilisation</a>.
                        </p>
                    </div>
                </div>

                <!-- SCREEN: FEED -->
                <div id="screen-feed" class="screen bg-gray-50">
                    <header class="bg-white p-4 sticky top-0 z-30 border-b border-gray-100">
                        <div class="flex items-center gap-3 mb-4">
                            <div class="flex-1 relative">
                                <i class="fas fa-search absolute left-4 top-1/2 -translate-y-1/2 text-gray-400"></i>
                                <input type="text" placeholder="Rechercher sur SombaTeka..." class="w-full bg-gray-100 rounded-2xl py-3 pl-12 pr-12 text-sm font-medium outline-none">
                                <button onclick="simulateImageSearch()" class="absolute right-4 top-1/2 -translate-y-1/2 text-blue-600"><i class="fas fa-camera"></i></button>
                            </div>
                            <button onclick="showFilters()" class="w-12 h-12 bg-white border border-gray-100 rounded-2xl flex items-center justify-center text-gray-600"><i class="fas fa-sliders"></i></button>
                        </div>
                        <div id="category-bar" class="flex gap-2 overflow-x-auto no-scrollbar pb-1"></div>
                    </header>
                    <div class="p-4 grid grid-cols-2 gap-4" id="feed-grid"></div>
                </div>

                <!-- SCREEN: FAVORITES -->
                <div id="screen-favorites" class="screen bg-white">
                    <header class="p-6 border-b border-gray-50 flex justify-between items-center"><h2 class="text-2xl font-black">Favoris</h2></header>
                    <div class="flex-1 flex flex-col items-center justify-center p-8 text-center">
                        <div class="w-24 h-24 bg-gray-50 rounded-[40px] flex items-center justify-center text-gray-200 mb-6"><i class="fas fa-heart text-4xl"></i></div>
                        <h3 class="text-xl font-black text-gray-900 mb-2">Aucun favori</h3>
                        <p class="text-gray-400 text-sm mb-8">Enregistrez les articles qui vous plaisent.</p>
                        <button onclick="showScreen('feed')" class="btn-primary py-4 px-8 w-auto">Découvrir</button>
                    </div>
                </div>

                <!-- SCREEN: PUBLISH -->
                <div id="screen-publish" class="screen bg-white p-6">
                    <h2 class="text-2xl font-black mb-6">Publier une annonce</h2>
                    <div class="space-y-6">
                        <div class="w-full aspect-video bg-gray-50 rounded-3xl border-2 border-dashed border-gray-200 flex flex-col items-center justify-center text-gray-400">
                            <i class="fas fa-camera text-3xl mb-2"></i>
                            <span class="text-xs font-bold uppercase">Ajouter des photos</span>
                        </div>
                        <input type="text" placeholder="Titre de l'annonce" class="w-full bg-gray-50 p-4 rounded-2xl outline-none font-medium">
                        <textarea placeholder="Description détaillée" rows="4" class="w-full bg-gray-50 p-4 rounded-2xl outline-none font-medium"></textarea>
                        <div class="flex gap-4">
                            <input type="number" placeholder="Prix ($)" class="flex-1 bg-gray-50 p-4 rounded-2xl outline-none font-medium">
                            <select class="flex-1 bg-gray-50 p-4 rounded-2xl outline-none font-medium">
                                <option>Kinshasa</option>
                                <option>Lubumbashi</option>
                                <option>Goma</option>
                            </select>
                        </div>
                        <button onclick="publishItem()" class="btn-primary py-5 mt-4">Publier maintenant</button>
                    </div>
                </div>

                <!-- SCREEN: MESSAGES LIST -->
                <div id="screen-messages-list" class="screen bg-white">
                    <header class="p-6 border-b border-gray-50 flex justify-between items-center"><h2 class="text-2xl font-black">Messages</h2></header>
                    <div id="messages-list-container" class="divide-y divide-gray-50">
                        <!-- Dynamic content -->
                    </div>
                </div>

                <!-- SCREEN: CHAT VIEW -->
                <div id="screen-chat-view" class="screen bg-white" id="chat-view-container"></div>

                <!-- SCREEN: PROFILE -->
                <div id="screen-profile" class="screen bg-gray-50">
                    <div class="bg-white p-8 rounded-b-[40px] shadow-sm text-center">
                        <div class="w-24 h-24 st-gradient rounded-[40px] mx-auto flex items-center justify-center text-white text-4xl mb-4 shadow-xl shadow-blue-100 border-4 border-white">ST</div>
                        <h2 id="profile-name" class="text-2xl font-black text-gray-900">Chargement...</h2>
                        <p id="profile-phone" class="text-gray-400 text-sm mt-1"></p>
                        <div class="flex justify-center gap-2 mt-4">
                            <span id="profile-badge" class="bg-blue-50 text-blue-600 text-[10px] font-black px-3 py-1 rounded-full uppercase tracking-widest border border-blue-100" style="display: none;">Compte Vérifié</span>
                        </div>
                    </div>
                    <div class="p-6 space-y-4">
                        <div class="bg-white p-4 rounded-2xl flex items-center justify-between shadow-sm">
                            <div class="flex items-center gap-4">
                                <div class="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center text-blue-600"><i class="fas fa-wallet"></i></div>
                                <div><p class="text-[10px] text-gray-400 font-bold uppercase">Solde Mobile Money</p><p class="font-black text-lg">450.00 $</p></div>
                            </div>
                            <button class="text-blue-600 font-bold text-sm">Recharger</button>
                        </div>
                        <div class="bg-white rounded-3xl overflow-hidden shadow-sm divide-y divide-gray-50">
                            <div class="p-4 flex items-center justify-between cursor-pointer hover:bg-gray-50">
                                <div class="flex items-center gap-4"><i class="fas fa-box text-gray-400"></i><span class="font-bold text-gray-700">Mes annonces</span></div>
                                <i class="fas fa-chevron-right text-gray-300"></i>
                            </div>
                            <div class="p-4 flex items-center justify-between cursor-pointer hover:bg-gray-50">
                                <div class="flex items-center gap-4"><i class="fas fa-bell text-gray-400"></i><span class="font-bold text-gray-700">Notifications</span></div>
                                <span class="bg-red-500 text-white text-[10px] px-2 py-0.5 rounded-full">3</span>
                            </div>
                            <div class="p-4 flex items-center justify-between cursor-pointer hover:bg-gray-50">
                                <div class="flex items-center gap-4"><i class="fas fa-shield-halved text-gray-400"></i><span class="font-bold text-gray-700">Sécurité</span></div>
                                <i class="fas fa-chevron-right text-gray-300"></i>
                            </div>
                            <div onclick="localStorage.removeItem('token'); location.reload()" class="p-4 flex items-center justify-between cursor-pointer hover:bg-red-50 text-red-500">
                                <div class="flex items-center gap-4"><i class="fas fa-power-off"></i><span class="font-bold">Déconnexion</span></div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- SCREEN: DETAIL -->
                <div id="screen-detail" class="screen bg-white">
                    <div class="relative aspect-square">
                        <img src="https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800&q=80" class="w-full h-full object-cover">
                        <button onclick="showScreen('feed')" class="absolute top-6 left-6 w-10 h-10 bg-white/80 backdrop-blur rounded-full flex items-center justify-center shadow-lg"><i class="fas fa-arrow-left"></i></button>
                    </div>
                    <div class="p-6">
                        <div class="flex justify-between items-start mb-4">
                            <div>
                                <h2 id="detail-title" class="text-2xl font-black text-gray-900 leading-tight"></h2>
                                <p class="text-blue-600 font-black text-2xl mt-2" id="detail-price"></p>
                            </div>
                            <button class="w-12 h-12 bg-gray-50 rounded-2xl flex items-center justify-center text-gray-300"><i class="fas fa-heart"></i></button>
                        </div>
                        <div class="bg-blue-50 p-4 rounded-2xl flex items-center gap-4 mb-6">
                            <div class="w-12 h-12 bg-blue-600 rounded-xl flex items-center justify-center text-white font-bold">ST</div>
                            <div class="flex-1">
                                <h4 class="font-bold text-blue-900 text-sm">Vendeur Officiel</h4>
                                <p class="text-[10px] text-blue-600 font-bold uppercase tracking-widest">Membre SombaTeka Pro</p>
                            </div>
                        </div>
                        <h4 class="font-black text-gray-900 mb-2 uppercase text-xs tracking-widest">Description</h4>
                        <p id="detail-desc" class="text-gray-500 text-sm leading-relaxed mb-8"></p>
                        <button id="contact-btn" class="btn-primary py-5 shadow-xl shadow-blue-200">
                            <i class="fas fa-comment-dots"></i> <span>Contacter le vendeur</span>
                        </button>
                    </div>
                </div>

                <!-- BOTTOM NAV -->
                <nav id="bottom-nav" class="absolute bottom-0 inset-x-0 bg-white/90 backdrop-blur-xl border-t border-gray-100 px-6 py-3 flex justify-between items-center z-40 hidden">
                    <button onclick="showScreen('feed')" class="flex flex-col items-center gap-1 text-blue-600"><i class="fas fa-house-chimney text-xl"></i><span class="text-[9px] font-bold">Accueil</span></button>
                    <button onclick="showScreen('favorites')" class="flex flex-col items-center gap-1 text-gray-400"><i class="fas fa-heart text-xl"></i><span class="text-[9px] font-bold">Favoris</span></button>
                    <button onclick="showScreen('publish')" class="w-12 h-12 st-gradient rounded-2xl flex items-center justify-center text-white shadow-lg -mt-8 border-4 border-white"><i class="fas fa-plus text-xl"></i></button>
                    <button onclick="showScreen('messages-list')" class="flex flex-col items-center gap-1 text-gray-400"><i class="fas fa-comment-dots text-xl"></i><span class="text-[9px] font-bold">Messages</span></button>
                    <button onclick="showScreen('profile')" class="flex flex-col items-center gap-1 text-gray-400"><i class="fas fa-user text-xl"></i><span class="text-[9px] font-bold">Profil</span></button>
                </nav>

                <!-- MODALS -->
                <div id="filter-modal" class="modal">
                    <div class="modal-content">
                        <div class="flex justify-between items-center mb-8"><h3 class="text-2xl font-black">Filtres</h3><button onclick="closeFilters()"><i class="fas fa-times text-gray-400"></i></button></div>
                        <div class="space-y-6">
                            <div><p class="font-black text-xs uppercase tracking-widest text-gray-400 mb-4">Prix Maximum</p><input type="range" class="w-full accent-blue-600"></div>
                            <div>
                                <p class="font-black text-xs uppercase tracking-widest text-gray-400 mb-4">Ville</p>
                                <div class="flex flex-wrap gap-2">
                                    <span class="px-4 py-2 bg-blue-600 text-white rounded-xl text-xs font-bold">Toutes</span>
                                    <span class="px-4 py-2 bg-gray-50 rounded-xl text-xs font-bold">Kinshasa</span>
                                    <span class="px-4 py-2 bg-gray-50 rounded-xl text-xs font-bold">Lubumbashi</span>
                                    <span class="px-4 py-2 bg-gray-50 rounded-xl text-xs font-bold">Goma</span>
                                </div>
                            </div>
                            <div>
                                <p class="font-black text-xs uppercase tracking-widest text-gray-400 mb-4">Type de compte</p>
                                <div class="flex gap-2">
                                    <button class="flex-1 py-3 bg-blue-50 text-blue-600 rounded-xl font-bold text-xs border border-blue-100">Tous</button>
                                    <button class="flex-1 py-3 bg-gray-50 text-gray-400 rounded-xl font-bold text-xs">Officiels uniquement</button>
                                </div>
                            </div>
                            <button onclick="closeFilters(); renderFeed()" class="btn-primary py-5 mt-4">Appliquer les filtres</button>
                        </div>
                    </div>
                </div>

                <div id="tos-modal" class="modal">
                    <div class="modal-content">
                        <div class="flex justify-between items-center mb-6"><h3 class="text-xl font-black">Conditions d'Utilisation</h3><button onclick="closeTOS()"><i class="fas fa-times"></i></button></div>
                        <div class="text-sm text-gray-500 space-y-4 leading-relaxed overflow-y-auto max-h-[60vh]">
                            <p class="font-bold text-gray-900">1. Acceptation des termes</p>
                            <p>En utilisant SombaTeka, vous acceptez de respecter nos règles de sécurité et de courtoisie...</p>
                            <p class="font-bold text-gray-900">2. Ventes et Locations</p>
                            <p>Les vendeurs sont responsables de la véracité de leurs annonces. Les comptes officiels sont vérifiés par notre équipe.</p>
                            <p class="font-bold text-gray-900">3. Paiements</p>
                            <p>Les paiements via Mobile Money sont sécurisés. SombaTeka ne prend aucune commission sur les ventes entre particuliers.</p>
                        </div>
                    </div>
                </div>

            </div>
            <script>
                // Initial load
                window.onload = async () => {
                    if (localStorage.getItem('token')) {
                        await fetchMe();
                        if (currentUser) {
                            await fetchCategories();
                            await renderFeed();
                            showScreen('feed');
                        }
                    }
                }
            </script>
        </body>
        </html>
        """

    @app.get("/healthz")
    @app.get("/health")
    def healthz() -> dict:
        from app.services.redis_client import get_redis

        redis_ok = False
        r = get_redis()
        if r:
            try:
                redis_ok = r.ping()
            except Exception:
                redis_ok = False
        return {
            "ok": True,
            "redis": redis_ok,
            "environment": settings.environment,
            "sentry": bool(settings.sentry_dsn.strip()),
            "email_provider": settings.email_provider,
        }

    return app


app = create_app()

