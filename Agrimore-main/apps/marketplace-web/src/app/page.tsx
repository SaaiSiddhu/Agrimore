'use client';

import { useEffect, useState } from 'react';

export default function Home() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll);
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <>
      {/* ─── NAVBAR ─── */}
      <nav className={`navbar${scrolled ? ' scrolled' : ''}`}>
        <div className="container nav-inner">
          <a href="/" className="nav-logo">
            <div className="nav-logo-icon">🌱</div>
            <span className="nav-logo-text">Agrimore</span>
          </a>

          <ul className="nav-links">
            <li><a href="#features">Features</a></li>
            <li><a href="#how-it-works">How It Works</a></li>
            <li><a href="#sellers">For Sellers</a></li>
            <li>
              <a
                href="https://agrimore-66a4e.web.app"
                className="nav-cta"
                target="_blank"
                rel="noopener noreferrer"
              >
                Shop
              </a>
            </li>
          </ul>

          <button className="hamburger" aria-label="Menu">
            <span></span>
            <span></span>
            <span></span>
          </button>
        </div>
      </nav>

      {/* ─── HERO ─── */}
      <section className="hero" id="hero">
        <div className="hero-content">
          <div className="hero-badge">
            <span className="hero-badge-dot"></span>
            Now serving Theni District
          </div>

          <h1 className="hero-title">
            From Farm to<br />
            <span>Your Doorstep</span>
          </h1>

          <p className="hero-desc">
            Connect with local farmers &amp; sellers. Fresh products, fair
            prices, no middlemen.
          </p>

          <div className="hero-buttons">
            <a
              href="https://agrimore-66a4e.web.app"
              className="btn-primary"
              target="_blank"
              rel="noopener noreferrer"
            >
              🛒 Start Selling
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 12h14M12 5l7 7-7 7" />
              </svg>
            </a>
            <a
              href="https://agrimore-66a4e.web.app"
              className="btn-secondary"
              target="_blank"
              rel="noopener noreferrer"
            >
              Shop Now
            </a>
          </div>

          <div className="hero-trust">
            <div className="trust-item">
              <span className="trust-icon">✅</span> Verified Sellers
            </div>
            <div className="trust-item">
              <span className="trust-icon">🚚</span> Fast Delivery
            </div>
            <div className="trust-item">
              <span className="trust-icon">🔒</span> Secure Payments
            </div>
          </div>
        </div>
      </section>

      {/* ─── FEATURES ─── */}
      <section className="features section" id="features">
        <div className="container">
          <div className="section-header">
            <span className="section-label">Why Agrimore?</span>
            <h2 className="section-title">Everything you need, farm-fresh</h2>
            <p className="section-desc">
              From harvest to your home in the shortest time possible, with full
              transparency.
            </p>
          </div>

          <div className="features-grid">
            {features.map((f) => (
              <div className="feature-card" key={f.title}>
                <div className="feature-icon">{f.icon}</div>
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── HOW IT WORKS ─── */}
      <section className="how-it-works section" id="how-it-works">
        <div className="container">
          <div className="section-header">
            <span className="section-label">Simple Process</span>
            <h2 className="section-title">How it works</h2>
            <p className="section-desc">
              Get fresh produce delivered in just 4 easy steps
            </p>
          </div>

          <div className="steps-grid">
            {steps.map((s) => (
              <div className="step-card" key={s.num}>
                <div className="step-number">{s.num}</div>
                <div className="step-icon">{s.icon}</div>
                <h3>{s.title}</h3>
                <p>{s.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── STATS ─── */}
      <section className="stats">
        <div className="container">
          <div className="stats-grid">
            {stats.map((s) => (
              <div className="stat-item" key={s.label}>
                <h3>{s.value}</h3>
                <p>{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── SELLER CTA ─── */}
      <section className="seller-cta section" id="sellers">
        <div className="container">
          <div className="seller-cta-card">
            <div className="seller-cta-content">
              <h2>Start selling on Agrimore today</h2>
              <p>
                Join hundreds of farmers and local sellers already growing their
                business with Agrimore. No commission on your first 100 orders.
              </p>

              <div className="seller-benefits">
                {sellerBenefits.map((b) => (
                  <div className="benefit" key={b}>
                    <span className="benefit-icon">✓</span>
                    {b}
                  </div>
                ))}
              </div>

              <a
                href="https://agrimore-66a4e.web.app"
                className="btn-primary"
                target="_blank"
                rel="noopener noreferrer"
              >
                🛒 Register as Seller
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M5 12h14M12 5l7 7-7 7" />
                </svg>
              </a>
            </div>

            <div className="seller-cta-visual">🌾</div>
          </div>
        </div>
      </section>

      {/* ─── DOWNLOAD ─── */}
      <section className="download section" id="download">
        <div className="container">
          <h2>Get the Agrimore app</h2>
          <p>
            Download now and start ordering fresh produce directly from local
            farmers.
          </p>
          <div className="download-buttons">
            <a href="#" className="store-btn">
              <span style={{ fontSize: 28 }}>▶</span>
              <div className="store-btn-text">
                <small>GET IT ON</small>
                <strong>Google Play</strong>
              </div>
            </a>
            <a href="#" className="store-btn">
              <span style={{ fontSize: 28 }}></span>
              <div className="store-btn-text">
                <small>Download on the</small>
                <strong>App Store</strong>
              </div>
            </a>
          </div>
        </div>
      </section>

      {/* ─── FOOTER ─── */}
      <footer className="footer">
        <div className="container">
          <div className="footer-grid">
            <div className="footer-brand">
              <div className="nav-logo">
                <div className="nav-logo-icon">🌱</div>
                <span className="nav-logo-text" style={{ color: '#fff' }}>
                  Agrimore
                </span>
              </div>
              <p>
                Connecting local farmers directly with consumers. Fresh
                products, fair prices, zero middlemen — serving Theni District
                and expanding soon.
              </p>
            </div>

            <div className="footer-col">
              <h4>Company</h4>
              <ul>
                <li><a href="#">About Us</a></li>
                <li><a href="#">Careers</a></li>
                <li><a href="#">Blog</a></li>
                <li><a href="#">Contact</a></li>
              </ul>
            </div>

            <div className="footer-col">
              <h4>Support</h4>
              <ul>
                <li><a href="#">Help Center</a></li>
                <li><a href="#">Safety</a></li>
                <li><a href="#">Terms</a></li>
                <li><a href="#">Privacy</a></li>
              </ul>
            </div>

            <div className="footer-col">
              <h4>For Sellers</h4>
              <ul>
                <li><a href="#">Register</a></li>
                <li><a href="#">Seller Guide</a></li>
                <li><a href="#">Pricing</a></li>
                <li><a href="#">Success Stories</a></li>
              </ul>
            </div>
          </div>

          <div className="footer-bottom">
            <span>© {new Date().getFullYear()} Agrimore. All rights reserved.</span>
            <div className="footer-socials">
              <a href="#" aria-label="Facebook">f</a>
              <a href="#" aria-label="Twitter">𝕏</a>
              <a href="#" aria-label="Instagram">📷</a>
              <a href="#" aria-label="YouTube">▶</a>
            </div>
          </div>
        </div>
      </footer>
    </>
  );
}

/* ── Data ── */

const features = [
  {
    icon: '🥬',
    title: 'Farm-Fresh Produce',
    desc: 'Handpicked vegetables, fruits, and grains sourced directly from verified local farmers in Theni District.',
  },
  {
    icon: '💰',
    title: 'Fair Pricing',
    desc: 'No middlemen means farmers earn more and you pay less. Transparent pricing on every product.',
  },
  {
    icon: '🚚',
    title: 'Fast Delivery',
    desc: 'Same-day and next-day delivery options. Track your order in real-time from farm to doorstep.',
  },
  {
    icon: '🔒',
    title: 'Secure Payments',
    desc: 'Multiple payment options including UPI, cards, and cash on delivery. Fully encrypted and safe.',
  },
  {
    icon: '⭐',
    title: 'Verified Sellers',
    desc: 'Every seller is verified and rated by the community. Quality and trust you can count on.',
  },
  {
    icon: '🎁',
    title: 'Rewards & Offers',
    desc: 'Earn reward points on every order. Exclusive coupons and seasonal discounts for loyal customers.',
  },
];

const steps = [
  { num: 1, icon: '🔍', title: 'Browse Products', desc: 'Explore fresh produce from local farmers near you.' },
  { num: 2, icon: '🛒', title: 'Add to Cart', desc: 'Select the items you need, choose quantities.' },
  { num: 3, icon: '💳', title: 'Checkout', desc: 'Pay securely via UPI, cards, or cash on delivery.' },
  { num: 4, icon: '📦', title: 'Get Delivered', desc: 'Receive fresh produce at your doorstep.' },
];

const stats = [
  { value: '500+', label: 'Local Farmers' },
  { value: '10,000+', label: 'Happy Customers' },
  { value: '50,000+', label: 'Orders Delivered' },
  { value: '4.8★', label: 'App Rating' },
];

const sellerBenefits = [
  'Zero setup cost',
  'Free listing',
  'Instant payouts',
  'Delivery support',
  'Growth analytics',
  'Dedicated manager',
];
