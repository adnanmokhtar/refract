import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { LoginPage } from './pages/LoginPage';
import { ProductPage } from './pages/ProductPage';
import { ProductEditor } from './pages/seller/ProductEditor';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/p/:id" element={<ProductPage />} />
        <Route path="/seller/products/:id" element={<ProductEditor />} />
      </Routes>
    </BrowserRouter>
  </React.StrictMode>,
);
