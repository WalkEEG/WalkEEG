/* ===========================================
   WalkEEG - Main JavaScript
   =========================================== */

document.addEventListener('DOMContentLoaded', () => {
  initNavbar();
  initScrollAnimations();
  initSmoothScroll();
});

/* ===== Navbar ===== */
function initNavbar() {
  const navbar = document.getElementById('navbar');
  const toggle = document.getElementById('navToggle');
  const links = document.getElementById('navLinks');

  // Scroll effect
  window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  });

  // Mobile toggle
  toggle.addEventListener('click', () => {
    links.classList.toggle('open');
    toggle.textContent = links.classList.contains('open') ? '✕' : '☰';
  });

  // Close on link click
  links.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      links.classList.remove('open');
      toggle.textContent = '☰';
    });
  });
}

/* ===== Scroll Animations ===== */
function initScrollAnimations() {
  const elements = document.querySelectorAll('.fade-in');

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  });

  elements.forEach(el => observer.observe(el));
}

/* ===== Smooth Scroll ===== */
function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', e => {
      const target = document.querySelector(anchor.getAttribute('href'));
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });
}

/* ===== API Client ===== */
const API = {
  BASE_URL: '/api',

  async request(endpoint, options = {}) {
    const token = localStorage.getItem('walkeeg_token');
    const headers = {
      'Content-Type': 'application/json',
      ...(token && { 'Authorization': `Bearer ${token}` }),
      ...options.headers,
    };

    try {
      const res = await fetch(`${API.BASE_URL}${endpoint}`, { ...options, headers });
      const data = await res.json();
      if (!res.ok) throw { status: res.status, ...data };
      return data;
    } catch (err) {
      if (err.status === 401) {
        localStorage.removeItem('walkeeg_token');
        window.location.hash = '#login';
      }
      throw err;
    }
  },

  get(endpoint) { return API.request(endpoint); },
  post(endpoint, body) { return API.request(endpoint, { method: 'POST', body: JSON.stringify(body) }); },
  put(endpoint, body) { return API.request(endpoint, { method: 'PUT', body: JSON.stringify(body) }); },
  delete(endpoint) { return API.request(endpoint, { method: 'DELETE' }); },
};
