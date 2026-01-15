'use client';

import Link from 'next/link';
import { useState } from 'react';
import { usePrivy, useWallets } from '@privy-io/react-auth';
import { useLoans } from '@/hooks/useLoans';
import { useMarketStats } from '@/hooks/useMarketStats';
import { useTransactions } from '@/hooks/useTransactions';
import { TOKENS } from '@/config/privy';

export default function ProtocolPage() {
  const { login, logout, authenticated, user } = usePrivy();
  const { wallets } = useWallets();
  const wallet = wallets[0];
  
  const { loans, loading: loansLoading, refetch } = useLoans();
  const { stats, loading: statsLoading } = useMarketStats();
  const { createLoan, fundLoan, loading: txLoading } = useTransactions();
  
  const [currentPage, setCurrentPage] = useState<'lend' | 'borrow' | 'portfolio' | 'markets'>('lend');
  const [activeTab, setActiveTab] = useState('all');
  const [activeFilter, setActiveFilter] = useState('all');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [modalType, setModalType] = useState<'create' | 'fund' | null>(null);
  const [selectedLoan, setSelectedLoan] = useState<any>(null);
  
  const [formData, setFormData] = useState({
    principalToken: TOKENS.USDC,
    principalAmount: '',
    interestRate: '',
    duration: '',
    collateralToken: TOKENS.WETH,
    collateralAmount: '',
    isPrivate: false,
  });

  const formatAddress = (address: string) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  const openCreateModal = () => {
    if (!authenticated) {
      login();
      return;
    }
    setModalType('create');
    setModalOpen(true);
  };

  const openFundModal = (loan: any) => {
    if (!authenticated) {
      login();
      return;
    }
    setSelectedLoan(loan);
    setModalType('fund');
    setModalOpen(true);
  };

  const handleCreateLoan = async () => {
    try {
      await createLoan({
        principalToken: formData.principalToken,
        principalAmount: formData.principalAmount,
        interestRate: parseFloat(formData.interestRate),
        duration: parseInt(formData.duration),
        collateralToken: formData.collateralToken,
        collateralAmount: formData.collateralAmount,
        isPrivate: formData.isPrivate,
      });
      
      setModalOpen(false);
      refetch();
      
      setFormData({
        principalToken: TOKENS.USDC,
        principalAmount: '',
        interestRate: '',
        duration: '',
        collateralToken: TOKENS.WETH,
        collateralAmount: '',
        isPrivate: false,
      });
    } catch (error) {
      console.error('Create loan failed:', error);
    }
  };

  const handleFundLoan = async () => {
    if (!selectedLoan) return;
    try {
      await fundLoan(selectedLoan.id);
      setModalOpen(false);
      refetch();
    } catch (error) {
      console.error('Fund loan failed:', error);
    }
  };

  const filterLoans = (filterType?: string) => {
    let filtered = loans.filter(loan => {
      if (filterType && loan.type !== filterType) return false;
      if (activeTab === 'public' && loan.private) return false;
      if (activeTab === 'private' && !loan.private) return false;
      return true;
    });

    if (activeFilter !== 'all') {
      filtered = filtered.filter(loan => {
        if (activeFilter === 'erc20') return loan.collateral.includes('WETH') || loan.collateral.includes('USDC');
        if (activeFilter === 'nft') return loan.collateral.includes('NFT') && !loan.collateral.includes('Bundle');
        if (activeFilter === 'bundle') return loan.collateral.includes('Bundle');
        return true;
      });
    }

    return filtered;
  };

  const renderLoanCards = (filterType?: string) => {
    const filtered = filterLoans(filterType);

    if (loansLoading) {
      return (
        <div className="col-span-full text-center py-16">
          <div className="animate-spin w-8 h-8 border-4 border-[#00ff87] border-t-transparent rounded-full mx-auto"></div>
          <p className="mt-4 text-[rgba(255,255,255,0.5)]">Loading loans...</p>
        </div>
      );
    }

    if (filtered.length === 0) {
      return (
        <div className="col-span-full text-center py-16 text-[rgba(255,255,255,0.4)]">
          <h3 className="text-2xl mb-2">No loans available</h3>
          <p>Check back later or create your own offer</p>
        </div>
      );
    }

    return filtered.map(loan => (
      <div
        key={loan.id}
        className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.08)] rounded-xl p-6 transition-all hover:bg-[rgba(255,255,255,0.04)] hover:border-[rgba(0,255,135,0.3)] hover:translate-y-[-2px]"
      >
        <div className="flex justify-between items-start mb-4 flex-wrap gap-2">
          <span className="bg-[rgba(0,255,135,0.1)] text-[#00ff87] px-3 py-1 rounded text-xs font-semibold uppercase">
            {loan.type}
          </span>
          {loan.private && (
            <span className="bg-[rgba(138,43,226,0.2)] text-[#ba8dff] px-3 py-1 rounded text-xs font-semibold">
              🔒 Private
            </span>
          )}
        </div>
        <div className="text-3xl font-extrabold mb-4">{loan.amount}</div>
        {[
          { label: 'Collateral', value: loan.collateral },
          { label: 'APY', value: loan.apy },
          { label: 'Duration', value: loan.duration },
          { label: 'LTV', value: loan.ltv }
        ].map((detail, i) => (
          <div key={i} className="flex justify-between py-3 border-b border-[rgba(255,255,255,0.05)] last:border-b-0">
            <span className="text-[rgba(255,255,255,0.5)] text-sm">{detail.label}</span>
            <span className="text-white font-semibold text-sm">{detail.value}</span>
          </div>
        ))}
        <div className="flex gap-3 mt-5">
          <button
            onClick={() => openFundModal(loan)}
            disabled={txLoading}
            className="flex-1 bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] py-3 rounded-md font-semibold text-sm transition-all hover:translate-y-[-2px] disabled:opacity-50"
          >
            {loan.type === 'borrow' ? 'Fund Loan' : 'Accept Offer'}
          </button>
        </div>
      </div>
    ));
  };

  const renderMarketCards = () => {
    const markets = [
      { asset: 'USDC', totalLent: '$850K', totalBorrowed: '$680K', avgAPY: '11.2%', utilization: '80%', trending: true },
      { asset: 'DAI', totalLent: '$620K', totalBorrowed: '$450K', avgAPY: '9.8%', utilization: '73%', trending: false },
      { asset: 'WETH', totalLent: '$1.2M', totalBorrowed: '$980K', avgAPY: '13.5%', utilization: '82%', trending: true },
      { asset: 'USDT', totalLent: '$540K', totalBorrowed: '$380K', avgAPY: '10.5%', utilization: '70%', trending: false },
      { asset: 'MNT', totalLent: '$920K', totalBorrowed: '$750K', avgAPY: '14.2%', utilization: '85%', trending: true },
      { asset: 'LINK', totalLent: '$380K', totalBorrowed: '$280K', avgAPY: '12.8%', utilization: '74%', trending: false },
    ];

    return markets.map((market, i) => (
      <div key={i} className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.08)] rounded-xl p-6 transition-all hover:bg-[rgba(255,255,255,0.04)] hover:border-[rgba(0,255,135,0.3)] hover:translate-y-[-2px]">
        <div className="flex justify-between items-start mb-4 flex-wrap gap-2">
          <span className="bg-[rgba(0,255,135,0.1)] text-[#00ff87] px-3 py-1 rounded text-xs font-semibold uppercase">
            {market.asset}
          </span>
          {market.trending && (
            <span className="bg-[rgba(255,165,0,0.2)] text-[#ffa500] px-3 py-1 rounded text-xs font-semibold">
              🔥 Trending
            </span>
          )}
        </div>
        <div className="text-3xl font-extrabold mb-4">{market.avgAPY}</div>
        {[
          { label: 'Total Lent', value: market.totalLent },
          { label: 'Total Borrowed', value: market.totalBorrowed },
          { label: 'Utilization', value: market.utilization }
        ].map((detail, i) => (
          <div key={i} className="flex justify-between py-3 border-b border-[rgba(255,255,255,0.05)] last:border-b-0">
            <span className="text-[rgba(255,255,255,0.5)] text-sm">{detail.label}</span>
            <span className="text-white font-semibold text-sm">{detail.value}</span>
          </div>
        ))}
      </div>
    ));
  };

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white">
      {/* Navigation */}
      <nav className="flex justify-between items-center px-6 md:px-8 py-5 border-b border-[rgba(255,255,255,0.05)] bg-[rgba(10,10,10,0.95)] backdrop-blur-[10px] sticky top-0 z-[100]">
        <Link href="/" className="flex items-center gap-2 text-xl font-extrabold cursor-pointer">
          <svg width="28" height="28" viewBox="0 0 32 32" fill="none">
            <path d="M16 2L4 10v12l12 8 12-8V10L16 2z" fill="url(#g1)"/>
            <path d="M16 12l-6 4v4l6 4 6-4v-4l-6-4z" fill="#0a0a0a"/>
            <defs><linearGradient id="g1" x1="4" y1="2" x2="28" y2="30">
              <stop offset="0%" stopColor="#00ff87"/><stop offset="100%" stopColor="#00d4ff"/>
            </linearGradient></defs>
          </svg>
          <span className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">XERO</span>
        </Link>
        
        {/* Desktop Navigation */}
        <div className="hidden md:flex gap-8 items-center">
          <button
            className={`text-sm font-medium transition-colors ${currentPage === 'lend' ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.6)] hover:text-[#00ff87]'}`}
            onClick={() => { setCurrentPage('lend'); setActiveTab('all'); }}
          >
            Lend
          </button>
          <button
            className={`text-sm font-medium transition-colors ${currentPage === 'borrow' ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.6)] hover:text-[#00ff87]'}`}
            onClick={() => { setCurrentPage('borrow'); setActiveTab('all'); }}
          >
            Borrow
          </button>
          <button
            className={`text-sm font-medium transition-colors ${currentPage === 'portfolio' ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.6)] hover:text-[#00ff87]'}`}
            onClick={() => { setCurrentPage('portfolio'); setActiveTab('all'); }}
          >
            Portfolio
          </button>
          <button
            className={`text-sm font-medium transition-colors ${currentPage === 'markets' ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.6)] hover:text-[#00ff87]'}`}
            onClick={() => { setCurrentPage('markets'); setActiveTab('all'); }}
          >
            Markets
          </button>
        </div>
        
        {/* Desktop Wallet */}
        <div className="hidden md:block">
          {authenticated && wallet ? (
            <div className="flex items-center gap-3">
              <span className="text-sm text-[rgba(255,255,255,0.7)]">
                {formatAddress(wallet.address)}
              </span>
              <button
                onClick={logout}
                className="bg-[rgba(255,255,255,0.05)] text-white px-4 py-2 rounded-md font-semibold text-sm border border-[rgba(255,255,255,0.1)] hover:border-[#00ff87] transition-all"
              >
                Disconnect
              </button>
            </div>
          ) : (
            <button
              onClick={login}
              className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-6 py-2 rounded-md font-bold text-sm transition-transform hover:translate-y-[-2px]"
            >
              Connect Wallet
            </button>
          )}
        </div>
        
        {/* Mobile Menu Button */}
        <button 
          className="md:hidden p-2" 
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/>
          </svg>
        </button>
      </nav>

      {/* Mobile Menu */}
      {mobileMenuOpen && (
        <div className="fixed top-[70px] right-0 bg-[rgba(10,10,10,0.98)] backdrop-blur-[20px] border-l border-[rgba(255,255,255,0.05)] p-8 z-[99] flex flex-col gap-6 min-w-[250px] rounded-bl-xl">
          <button 
            className="text-[rgba(255,255,255,0.7)] font-medium text-left hover:text-[#00ff87]" 
            onClick={() => { setCurrentPage('lend'); setMobileMenuOpen(false); setActiveTab('all'); }}
          >
            Lend
          </button>
          <button 
            className="text-[rgba(255,255,255,0.7)] font-medium text-left hover:text-[#00ff87]" 
            onClick={() => { setCurrentPage('borrow'); setMobileMenuOpen(false); setActiveTab('all'); }}
          >
            Borrow
          </button>
          <button 
            className="text-[rgba(255,255,255,0.7)] font-medium text-left hover:text-[#00ff87]" 
            onClick={() => { setCurrentPage('portfolio'); setMobileMenuOpen(false); setActiveTab('all'); }}
          >
            Portfolio
          </button>
          <button 
            className="text-[rgba(255,255,255,0.7)] font-medium text-left hover:text-[#00ff87]" 
            onClick={() => { setCurrentPage('markets'); setMobileMenuOpen(false); setActiveTab('all'); }}
          >
            Markets
          </button>
          
          {authenticated && wallet ? (
            <>
              <div className="text-sm text-[rgba(255,255,255,0.5)] pt-4 border-t border-[rgba(255,255,255,0.1)]">
                {formatAddress(wallet.address)}
              </div>
              <button
                onClick={() => { logout(); setMobileMenuOpen(false); }}
                className="bg-[rgba(255,255,255,0.05)] text-white px-6 py-2 rounded-md font-bold text-sm w-full border border-[rgba(255,255,255,0.1)]"
              >
                Disconnect
              </button>
            </>
          ) : (
            <button
              onClick={() => { login(); setMobileMenuOpen(false); }}
              className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-6 py-2 rounded-md font-bold text-sm w-full"
            >
              Connect Wallet
            </button>
          )}
        </div>
      )}

      <div className="max-w-[1400px] mx-auto px-6 md:px-8 py-8">
        {/* LEND PAGE */}
        {currentPage === 'lend' && (
          <>
            <div className="mb-8">
              <h1 className="text-4xl font-extrabold mb-2">Lending Marketplace</h1>
              <p className="text-[rgba(255,255,255,0.5)]">Browse borrow requests and create lending offers</p>
            </div>
            
            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
              {[
                { label: 'Total Volume', value: statsLoading ? '...' : `$${stats.totalVolume}` },
                { label: 'Active Loans', value: statsLoading ? '...' : stats.activeLoans.toString() },
                { label: 'Avg. APY', value: statsLoading ? '...' : `${stats.avgAPY}%` },
                { label: 'Private Loans', value: statsLoading ? '...' : `${stats.privateLoanPercentage}%` }
              ].map((stat, i) => (
                <div key={i} className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.08)] rounded-xl p-6">
                  <div className="text-[rgba(255,255,255,0.5)] text-sm mb-2">{stat.label}</div>
                  <div className="text-3xl font-extrabold bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">{stat.value}</div>
                </div>
              ))}
            </div>
            
            {/* Tabs */}
            <div className="flex gap-2 mb-8 border-b border-[rgba(255,255,255,0.05)] overflow-x-auto">
              {['all', 'public', 'private', 'offers'].map(tab => (
                <button
                  key={tab}
                  className={`px-6 py-4 text-sm font-semibold relative whitespace-nowrap ${activeTab === tab ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.5)]'}`}
                  onClick={() => setActiveTab(tab)}
                >
                  {tab === 'all' ? 'All Requests' : tab === 'offers' ? 'My Offers' : tab.charAt(0).toUpperCase() + tab.slice(1)}
                  {activeTab === tab && (
                    <div className="absolute bottom-[-1px] left-0 w-full h-[2px] bg-gradient-to-r from-[#00ff87] to-[#00d4ff]" />
                  )}
                </button>
              ))}
            </div>
            
            {/* Filters */}
            <div className="flex flex-wrap gap-4 mb-8">
              {['all', 'erc20', 'nft', 'bundle'].map(filter => (
                <button
                  key={filter}
                  className={`px-5 py-2 rounded-md text-sm font-medium transition-all ${
                    activeFilter === filter
                      ? 'bg-[rgba(0,255,135,0.1)] border-[#00ff87] text-[#00ff87]'
                      : 'bg-[rgba(255,255,255,0.03)] text-[rgba(255,255,255,0.7)] hover:border-[#00ff87] hover:text-[#00ff87]'
                  } border`}
                  onClick={() => setActiveFilter(filter)}
                >
                  {filter === 'all' ? 'All Assets' : filter === 'erc20' ? 'ERC-20' : filter === 'nft' ? 'NFTs' : 'Bundles'}
                </button>
              ))}
            </div>
            
            <button
              className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-6 py-3 rounded-md font-semibold text-sm mb-6 transition-all hover:translate-y-[-2px] disabled:opacity-50"
              onClick={openCreateModal}
              disabled={txLoading}
            >
              + Create Lend Offer
            </button>
            
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {renderLoanCards()}
            </div>
          </>
        )}

        {/* BORROW PAGE */}
        {currentPage === 'borrow' && (
          <>
            <div className="mb-8">
              <h1 className="text-4xl font-extrabold mb-2">Borrowing Marketplace</h1>
              <p className="text-[rgba(255,255,255,0.5)]">Browse lending offers and create borrow requests</p>
            </div>
            
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
              {[
                { label: 'Available Liquidity', value: statsLoading ? '...' : `$${stats.availableLiquidity}` },
                { label: 'Best Rate', value: statsLoading ? '...' : `${stats.bestRate}%` },
                { label: 'Avg. Duration', value: statsLoading ? '...' : stats.avgDuration },
                { label: 'Max LTV', value: statsLoading ? '...' : `${stats.maxLTV}%` }
              ].map((stat, i) => (
                <div key={i} className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.08)] rounded-xl p-6">
                  <div className="text-[rgba(255,255,255,0.5)] text-sm mb-2">{stat.label}</div>
                  <div className="text-3xl font-extrabold bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">{stat.value}</div>
                </div>
              ))}
            </div>
            
            <div className="flex gap-2 mb-8 border-b border-[rgba(255,255,255,0.05)] overflow-x-auto">
              {['all', 'public', 'private', 'requests'].map(tab => (
                <button
                  key={tab}
                  className={`px-6 py-4 text-sm font-semibold relative whitespace-nowrap ${activeTab === tab ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.5)]'}`}
                  onClick={() => setActiveTab(tab)}
                >
                  {tab === 'all' ? 'All Offers' : tab === 'requests' ? 'My Requests' : tab.charAt(0).toUpperCase() + tab.slice(1)}
                  {activeTab === tab && (
                    <div className="absolute bottom-[-1px] left-0 w-full h-[2px] bg-gradient-to-r from-[#00ff87] to-[#00d4ff]" />
                  )}
                </button>
              ))}
            </div>
            
            <button
              className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-6 py-3 rounded-md font-semibold text-sm mb-6 transition-all hover:translate-y-[-2px]"
              onClick={openCreateModal}
            >
              + Create Borrow Request
            </button>
            
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {renderLoanCards('lend')}
            </div>
          </>
        )}

        {/* PORTFOLIO PAGE */}
        {currentPage === 'portfolio' && (
          <>
            <div className="mb-8">
              <h1 className="text-4xl font-extrabold mb-2">My Portfolio</h1>
              <p className="text-[rgba(255,255,255,0.5)]">Track your lending and borrowing activity</p>
            </div>
            
            {authenticated ? (
              <>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
                  {[
                    { label: 'Total Lent', value: '$0' },
                    { label: 'Total Borrowed', value: '$0' },
                    { label: 'Active Loans', value: '0' },
                    { label: 'Reputation Score', value: '0' }
                  ].map((stat, i) => (
                    <div key={i} className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.08)] rounded-xl p-6">
                      <div className="text-[rgba(255,255,255,0.5)] text-sm mb-2">{stat.label}</div>
                      <div className="text-3xl font-extrabold bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">{stat.value}</div>
                    </div>
                  ))}
                </div>
                
                <div className="flex gap-2 mb-8 border-b border-[rgba(255,255,255,0.05)] overflow-x-auto">
                  {['all', 'lending', 'borrowing', 'history'].map(tab => (
                    <button
                      key={tab}
                      className={`px-6 py-4 text-sm font-semibold relative whitespace-nowrap ${activeTab === tab ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.5)]'}`}
                      onClick={() => setActiveTab(tab)}
                    >
                      {tab === 'all' ? 'All Positions' : tab.charAt(0).toUpperCase() + tab.slice(1)}
                      {activeTab === tab && (
                        <div className="absolute bottom-[-1px] left-0 w-full h-[2px] bg-gradient-to-r from-[#00ff87] to-[#00d4ff]" />
                      )}
                    </button>
                  ))}
                </div>
                
                <div className="text-center py-16 text-[rgba(255,255,255,0.4)]">
                  <h3 className="text-2xl mb-2">No active positions</h3>
                  <p>Create a loan to get started</p>
                </div>
              </>
            ) : (
              <div className="text-center py-16 text-[rgba(255,255,255,0.4)]">
                <h3 className="text-2xl mb-2">Connect Your Wallet</h3>
                <p className="mb-4">Connect your wallet to view your portfolio</p>
                <button
                  className="bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] px-8 py-3 rounded-md font-semibold transition-all hover:translate-y-[-2px]"
                  onClick={login}
                >
                  Connect Wallet
                </button>
              </div>
            )}
          </>
        )}

        {/* MARKETS PAGE */}
        {currentPage === 'markets' && (
          <>
            <div className="mb-8">
              <h1 className="text-4xl font-extrabold mb-2">Market Overview</h1>
              <p className="text-[rgba(255,255,255,0.5)]">Explore lending markets and analytics</p>
            </div>
            
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
              {[
                { label: 'Total Value Locked', value: statsLoading ? '...' : `$${stats.totalVolume}` },
                { label: '24h Volume', value: '$0' },
                { label: 'Active Users', value: '0' },
                { label: 'Avg APY', value: statsLoading ? '...' : `${stats.avgAPY}%` }
              ].map((stat, i) => (
                <div key={i} className="bg-[rgba(255,255,255,0.02)] border border-[rgba(255,255,255,0.08)] rounded-xl p-6">
                  <div className="text-[rgba(255,255,255,0.5)] text-sm mb-2">{stat.label}</div>
                  <div className="text-3xl font-extrabold bg-gradient-to-br from-[#00ff87] to-[#00d4ff] bg-clip-text text-transparent">{stat.value}</div>
                </div>
              ))}
            </div>
            
            <div className="flex gap-2 mb-8 border-b border-[rgba(255,255,255,0.05)] overflow-x-auto">
              {['all', 'trending', 'highest'].map(tab => (
                <button
                  key={tab}
                  className={`px-6 py-4 text-sm font-semibold relative whitespace-nowrap ${activeTab === tab ? 'text-[#00ff87]' : 'text-[rgba(255,255,255,0.5)]'}`}
                  onClick={() => setActiveTab(tab)}
                >
                  {tab === 'all' ? 'All Markets' : tab === 'trending' ? 'Trending' : 'Highest APY'}
                  {activeTab === tab && (
                    <div className="absolute bottom-[-1px] left-0 w-full h-[2px] bg-gradient-to-r from-[#00ff87] to-[#00d4ff]" />
                  )}
                </button>
              ))}
            </div>
            
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
              {renderMarketCards()}
            </div>
          </>
        )}
      </div>

      {/* CREATE MODAL */}
      {modalOpen && modalType === 'create' && (
        <div className="fixed inset-0 bg-[rgba(0,0,0,0.8)] z-[200] flex items-center justify-center p-4" onClick={() => setModalOpen(false)}>
          <div className="bg-[#1a1a1a] border border-[rgba(255,255,255,0.1)] rounded-2xl p-8 max-w-[600px] w-full max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-3xl font-extrabold">
                {currentPage === 'borrow' ? 'Create Borrow Request' : 'Create Lend Offer'}
              </h2>
              <button className="text-[rgba(255,255,255,0.5)] text-2xl hover:text-white" onClick={() => setModalOpen(false)}>
                &times;
              </button>
            </div>
            
            <div className="flex items-center gap-4 p-4 bg-[rgba(138,43,226,0.1)] border border-[rgba(138,43,226,0.2)] rounded-lg mb-6">
              <div
                className={`relative w-[50px] h-[26px] rounded-full cursor-pointer transition-colors ${formData.isPrivate ? 'bg-[#00ff87]' : 'bg-[rgba(255,255,255,0.1)]'}`}
                onClick={() => setFormData(prev => ({ ...prev, isPrivate: !prev.isPrivate }))}
              >
                <div className={`absolute top-[3px] left-[3px] w-[20px] h-[20px] bg-white rounded-full transition-transform ${formData.isPrivate ? 'translate-x-[24px]' : ''}`} />
              </div>
              <div>
                <div className="font-semibold mb-1">Privacy Mode</div>
                <div className="text-sm text-[rgba(255,255,255,0.5)]">Hide loan details using zero-knowledge proofs</div>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="block mb-2 text-sm font-medium">Amount (USDC)</label>
                <input
                  type="number"
                  value={formData.principalAmount}
                  onChange={(e) => setFormData(prev => ({ ...prev, principalAmount: e.target.value }))}
                  className="w-full bg-[rgba(255,255,255,0.05)] border border-[rgba(255,255,255,0.1)] text-white px-4 py-3 rounded-md text-sm focus:outline-none focus:border-[#00ff87]"
                  placeholder="10000"
                />
              </div>

              <div>
                <label className="block mb-2 text-sm font-medium">APY (%)</label>
                <input
                  type="number"
                  value={formData.interestRate}
                  onChange={(e) => setFormData(prev => ({ ...prev, interestRate: e.target.value }))}
                  className="w-full bg-[rgba(255,255,255,0.05)] border border-[rgba(255,255,255,0.1)] text-white px-4 py-3 rounded-md text-sm focus:outline-none focus:border-[#00ff87]"
                  placeholder="10"
                />
              </div>

              <div>
                <label className="block mb-2 text-sm font-medium">Duration (days)</label>
                <input
                  type="number"
                  value={formData.duration}
                  onChange={(e) => setFormData(prev => ({ ...prev, duration: e.target.value }))}
                  className="w-full bg-[rgba(255,255,255,0.05)] border border-[rgba(255,255,255,0.1)] text-white px-4 py-3 rounded-md text-sm focus:outline-none focus:border-[#00ff87]"
                  placeholder="30"
                />
              </div>

              <div>
                <label className="block mb-2 text-sm font-medium">Collateral Amount (WETH)</label>
                <input
                  type="number"
                  step="0.01"
                  value={formData.collateralAmount}
                  onChange={(e) => setFormData(prev => ({ ...prev, collateralAmount: e.target.value }))}
                  className="w-full bg-[rgba(255,255,255,0.05)] border border-[rgba(255,255,255,0.1)] text-white px-4 py-3 rounded-md text-sm focus:outline-none focus:border-[#00ff87]"
                  placeholder="0.5"
                />
              </div>
            </div>

            <button
              onClick={handleCreateLoan}
              disabled={txLoading}
              className="w-full mt-6 bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] py-3 rounded-md font-semibold text-sm transition-all hover:translate-y-[-2px] disabled:opacity-50"
            >
              {txLoading ? 'Processing...' : `Create ${currentPage === 'borrow' ? 'Request' : 'Offer'}`}
            </button>
          </div>
        </div>
      )}

      {/* FUND MODAL */}
      {modalOpen && modalType === 'fund' && selectedLoan && (
        <div className="fixed inset-0 bg-[rgba(0,0,0,0.8)] z-[200] flex items-center justify-center p-4" onClick={() => setModalOpen(false)}>
          <div className="bg-[#1a1a1a] border border-[rgba(255,255,255,0.1)] rounded-2xl p-8 max-w-[600px] w-full" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-3xl font-extrabold">Loan Details</h2>
              <button className="text-[rgba(255,255,255,0.5)] text-2xl hover:text-white" onClick={() => setModalOpen(false)}>
                &times;
              </button>
            </div>
            
            <div className="text-3xl font-extrabold mb-6">{selectedLoan.amount}</div>
            
            {[
              { label: 'Collateral', value: selectedLoan.collateral },
              { label: 'APY', value: selectedLoan.apy },
              { label: 'Duration', value: selectedLoan.duration },
              { label: 'LTV', value: selectedLoan.ltv },
              { label: 'Privacy', value: selectedLoan.private ? '🔒 Private' : '🌐 Public' }
            ].map((detail, i) => (
              <div key={i} className="flex justify-between py-3 border-b border-[rgba(255,255,255,0.05)] last:border-b-0">
                <span className="text-[rgba(255,255,255,0.5)] text-sm">{detail.label}</span>
                <span className="text-white font-semibold text-sm">{detail.value}</span>
              </div>
            ))}
            
            <button
              onClick={handleFundLoan}
              disabled={txLoading}
              className="w-full mt-6 bg-gradient-to-br from-[#00ff87] to-[#00d4ff] text-[#0a0a0a] py-3 rounded-md font-semibold text-sm transition-all hover:translate-y-[-2px] disabled:opacity-50"
            >
              {txLoading ? 'Processing...' : 'Fund This Loan'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}