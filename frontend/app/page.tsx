'use client';

import { useState } from 'react';

export default function LandingPage() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white">
      <div className="fixed inset-0 pointer-events-none opacity-[0.03] z-[1]"
        style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`
        }}
      />

      <nav className="fixed top-0 w-full px-6 md:px-12 py-6 flex justify-between items-center z-[1000] bg-[rgba(10,10,10,0.8)] backdrop-blur-[10px] border-b border-[rgba(255,255,255,0.05)]">
        <div className="flex items-center gap-3 text-2xl font-extrabold tracking-tight">
          <svg width="32" height="32" viewBox="0 0 32 32" fill="none">
            <path d="M16 2L4 10v12l12 8 12-8V10L16 2z" fill="url(#grad1)"/>
            <path d="M16 12l-6 4v4l6 4 6-4v-4l-6-4z" fill="#0a0a0a"/>
            <defs>
              <linearGradient id="grad1" x1="4" y1="2" x2="28" y2="30">
                <stop offset="0%" style={{stopColor: '#00ff87'}}/>
                <stop offset="100%" style={{stopColor: '#00d4ff'}}/>
              </linearGradient>
            </defs> 
          </svg>
          <span className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">XERO</span>
        </div> 

        <div className="hidden md:flex gap-10 items-center">
          <a href="#features" className="text-[rgba(255,255,255,0.7)] text-sm font-medium hover:text-[#00ff87] transition-colors">Features</a>
          <a href="#products" className="text-[rgba(255,255,255,0.7)] text-sm font-medium hover:text-[#00ff87] transition-colors">Products</a>
          <a href="#technology" className="text-[rgba(255,255,255,0.7)] text-sm font-medium hover:text-[#00ff87] transition-colors">Technology</a>
          <a href="https://mantle.xeroprotocol.com/docs" className="text-[rgba(255,255,255,0.7)] text-sm font-medium hover:text-[#00ff87] transition-colors">Docs</a>
          <button 
            onClick={() => window.location.href = '/protocol'}
            className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-7 py-3 rounded-md font-semibold text-sm transition-all hover:translate-y-[-2px] hover:shadow-[0_10px_30px_rgba(0,255,135,0.3)]"
          >
            Launch App
          </button>
        </div>

        <button className="md:hidden p-2" onClick={() => setMobileMenuOpen(!mobileMenuOpen)}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/>
          </svg>
        </button>
      </nav>

      {mobileMenuOpen && (
        <div className="fixed top-[70px] right-0 bg-[rgba(10,10,10,0.98)] backdrop-blur-[20px] border-l border-[rgba(255,255,255,0.05)] p-8 z-[999] flex flex-col gap-6 min-w-[200px] rounded-bl-xl">
          <a href="#features" className="text-[rgba(255,255,255,0.7)] font-medium hover:text-[#00ff87]" onClick={() => setMobileMenuOpen(false)}>Features</a>
          <a href="#products" className="text-[rgba(255,255,255,0.7)] font-medium hover:text-[#00ff87]" onClick={() => setMobileMenuOpen(false)}>Products</a>
          <a href="#technology" className="text-[rgba(255,255,255,0.7)] font-medium hover:text-[#00ff87]" onClick={() => setMobileMenuOpen(false)}>Technology</a>
          <a href="https://mantle.xeroprotocol.com/docs" className="text-[rgba(255,255,255,0.7)] font-medium hover:text-[#00ff87]" onClick={() => setMobileMenuOpen(false)}>Docs</a>
          <button 
            onClick={() => window.location.href = '/protocol'}
            className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-7 py-3 rounded-md font-semibold text-sm w-full"
          >
            Launch App
          </button>
        </div>
      )}

      <section className="relative px-6 md:px-12 pt-48 md:pt-[12rem] pb-32 text-center overflow-hidden">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-[radial-gradient(circle,_rgba(0,255,135,0.15)_0%,_transparent_70%)] blur-[80px] z-0" />

        <div className="relative z-[2] max-w-[900px] mx-auto">
          <div className="flex items-center justify-center gap-4 mb-6">
            <span className="bg-[rgba(0,255,135,0.1)] text-[#00ff87] px-4 py-2 rounded-full text-sm font-semibold border border-[rgba(0,255,135,0.3)]">
              🟢 Incentivized Testnet Live
            </span>
            <span className="bg-[rgba(138,43,226,0.1)] text-[#ba8dff] px-4 py-2 rounded-full text-sm font-semibold border border-[rgba(138,43,226,0.3)]">
              🚀 Mainnet Q1 2026
            </span>
          </div>
          
          <h1 className="text-5xl md:text-7xl font-extrabold leading-[1.1] mb-6 tracking-tight">
            Privacy-Enhanced <br/>
            <span className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">P2P Lending & Borrowing</span>
          </h1>
          <p className="text-xl md:text-2xl text-[rgba(255,255,255,0.6)] mb-12 font-normal">
            Flexible peer-to-peer decentralized credit marketplace with optional privacy & cross-chain collateral support on Mantle.
          </p>
          <div className="flex flex-col sm:flex-row gap-6 justify-center">
            <button 
              onClick={() => window.location.href = '/protocol'}
              className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-10 py-4 rounded-lg font-bold transition-all hover:translate-y-[-3px] hover:shadow-[0_15px_40px_rgba(0,255,135,0.4)]"
            >
              Start Lending
            </button>
            <button  onClick={() => window.location.href = 'https://mantle.xeroprotocol.com/docs'} className="bg-transparent text-white px-10 py-4 rounded-lg font-semibold border-2 border-[rgba(255,255,255,0.2)] transition-all hover:border-[#00ff87] hover:text-[#00ff87]">
              Learn More
            </button>
          </div>
        </div>
      </section>

      <section className="px-6 md:px-12 py-24 bg-[rgba(255,255,255,0.02)] border-t border-b border-[rgba(255,255,255,0.05)]">
        <div className="max-w-[1200px] mx-auto grid grid-cols-2 md:grid-cols-4 gap-12">
          {[
            { value: '100%', label: 'Your Privacy Choice' },
            { value: '0', label: 'Liquidation Cascades' },
            { value: 'Any', label: 'Collateral Type Supported' },
            { value: '∞', label: 'Loan Customization' }
          ].map((stat, i) => (
            <div key={i} className="text-center">
              <div className="text-4xl md:text-5xl font-extrabold bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent mb-2">
                {stat.value}
              </div>
              <div className="text-sm md:text-base text-[rgba(255,255,255,0.5)] font-medium">
                {stat.label}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section id="features" className="px-6 md:px-12 py-32 max-w-[1400px] mx-auto">
        <div className="text-center mb-20">
          <h2 className="text-4xl md:text-5xl font-extrabold mb-4 tracking-tight">Built for Privacy & Flexibility</h2>
          <p className="text-lg md:text-xl text-[rgba(255,255,255,0.5)]">The lending protocol that adapts to your needs</p>
        </div>
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
          {[
            { icon: '🔒', title: 'Optional Privacy', desc: 'Choose exactly what to reveal. Keep loan amounts, collateral types, and interest rates private using zero-knowledge proofs, or operate transparently, it\'s your choice.' },
            { icon: '🎯', title: 'Custom Loan Terms', desc: 'No rigid parameters. Set your own interest rates, durations, and repayment schedules. True peer-to-peer negotiation for every loan.' },
            { icon: '💎', title: 'Universal Collateral', desc: 'Use any tokenized asset as collateral—ERC-20 tokens, NFTs, RWAs, or bundles combining multiple asset types in one loan.' },
            { icon: '⚡', title: 'No Liquidations', desc: 'Eliminate systemic risk with pre-agreed collateral claims. No cascading liquidations, no market impact, no slippage, just clear terms from day one.' },
            { icon: '🏆', title: 'On-Chain Reputation', desc: 'Build verifiable credit history. Prove your track record with zero-knowledge proofs without revealing specific loan details. Better reputation means better rates.' },
            { icon: '🚀', title: 'Built on Mantle', desc: 'Lightning-fast transactions at minimal cost on Mantle Network. Institutional-grade security with the affordability DeFi deserves.' }
          ].map((feature, i) => (
            <div key={i} className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.05)] rounded-2xl p-10 transition-all hover:bg-[rgba(255,255,255,0.04)] hover:border-[rgba(0,255,135,0.3)] hover:translate-y-[-5px]">
              <div className="w-[60px] h-[60px] bg-gradient-to-br from-[rgba(0,255,135,0.1)] to-[rgba(0,212,255,0.1)] rounded-xl flex items-center justify-center text-3xl mb-6">
                {feature.icon}
              </div>
              <h3 className="text-2xl font-bold mb-4">{feature.title}</h3>
              <p className="text-[rgba(255,255,255,0.6)] leading-relaxed">{feature.desc}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="products" className="px-6 md:px-12 py-32 bg-[rgba(255,255,255,0.01)]">
        <div className="text-center mb-20">
          <h2 className="text-4xl md:text-5xl font-extrabold mb-4 tracking-tight">Loan Products</h2>
          <p className="text-lg md:text-xl text-[rgba(255,255,255,0.5)]">Flexible lending solutions for every need</p>
        </div>
        <div className="max-w-[1200px] mx-auto grid md:grid-cols-2 gap-12">
          {[
            { icon: '💼', title: 'Simple Loans', desc: 'Standard P2P loans with fully customizable terms and instant execution.' },
            { icon: '📦', title: 'Bundle Loans', desc: 'Use multiple assets as collateral in a single loan agreement.' },
            { icon: '💳', title: 'Credit Lines', desc: 'Revolving credit facilities for trusted borrowers with proven history.' },
            { icon: '📋', title: 'Offer System', desc: 'Lenders create standing offers that borrowers can accept instantly.' }
          ].map((product, i) => (
            <div key={i} className="bg-[rgba(255,255,255,0.03)] border border-[rgba(255,255,255,0.08)] rounded-[20px] p-12">
              <h3 className="text-3xl font-extrabold mb-6">{product.icon} {product.title}</h3>
              <p className="text-[rgba(255,255,255,0.7)]">{product.desc}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="technology" className="px-6 md:px-12 py-32">
        <div className="text-center mb-20">
          <h2 className="text-4xl md:text-5xl font-extrabold mb-4 tracking-tight">Privacy Technology</h2>
          <p className="text-lg md:text-xl text-[rgba(255,255,255,0.5)]">Zero-knowledge proofs meet peer-to-peer lending</p>
        </div>
        <div className="max-w-[1200px] mx-auto grid md:grid-cols-2 gap-12">
          <div className="bg-[rgba(255,255,255,0.03)] border border-[rgba(255,255,255,0.08)] rounded-[20px] p-12">
            <h3 className="text-3xl font-extrabold mb-6">🌐 Public Mode</h3>
            <p className="text-[rgba(255,255,255,0.7)] mb-6">Fully transparent lending with complete on-chain visibility.</p>
            <ul className="space-y-4">
              {[
                { label: 'Transparent Terms:', desc: 'All amounts, rates visible' },
                { label: 'Public Reputation:', desc: 'Build visible credit history' },
                { label: 'Community Trust:', desc: 'Perfect for DAOs' }
              ].map((item, i) => (
                <li key={i} className="py-4 border-b border-[rgba(255,255,255,0.05)] text-[rgba(255,255,255,0.7)] last:border-b-0">
                  <strong className="text-[#00ff87] font-semibold">{item.label}</strong> {item.desc}
                </li>
              ))}
            </ul>
          </div>
          <div className="bg-[rgba(255,255,255,0.03)] border border-[rgba(255,255,255,0.08)] rounded-[20px] p-12">
            <h3 className="text-3xl font-extrabold mb-6">🔐 Privacy Mode</h3>
            <p className="text-[rgba(255,255,255,0.7)] mb-6">Confidential lending with ZK proof verification.</p>
            <ul className="space-y-4">
              {[
                { label: 'Hidden Amounts:', desc: 'Principals encrypted' },
                { label: 'Private Collateral:', desc: 'Prove value without revealing assets' },
                { label: 'Encrypted Rates:', desc: 'Keep terms confidential' },
                { label: 'Pseudonymous Credit:', desc: 'Prove reputation privately' }
              ].map((item, i) => (
                <li key={i} className="py-4 border-b border-[rgba(255,255,255,0.05)] text-[rgba(255,255,255,0.7)] last:border-b-0">
                  <strong className="text-[#00ff87] font-semibold">{item.label}</strong> {item.desc}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section className="px-6 md:px-12 py-32 text-center">
        <div className="max-w-[800px] mx-auto bg-gradient-to-br from-[rgba(0,255,135,0.05)] to-[rgba(0,212,255,0.05)] border border-[rgba(0,255,135,0.2)] rounded-[24px] p-12 md:p-16">
          <h2 className="text-3xl md:text-4xl font-extrabold mb-6">Ready to Experience True Financial Privacy?</h2>
          <p className="text-lg md:text-xl text-[rgba(255,255,255,0.6)] mb-10">Join the next generation of decentralized lending on Mantle Network</p>
          <button 
            onClick={() => window.location.href = '/protocol'}
            className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-10 py-4 rounded-lg font-bold transition-all hover:translate-y-[-3px] hover:shadow-[0_15px_40px_rgba(0,255,135,0.4)]"
          >
            Launch App
          </button>
        </div>
      </section>

      <footer className="px-12 py-12 text-center border-t border-[rgba(255,255,255,0.05)] text-[rgba(255,255,255,0.4)]">
        <p>&copy; 2026 Xero Protocol. Built on Mantle Network. Privacy is a right, not a luxury.</p>
      </footer>
    </div>
  );
}