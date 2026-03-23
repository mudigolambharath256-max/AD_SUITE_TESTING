import React from 'react';

const LoadingSpinner = ({ size = 'default', className = '' }) => {
  const sizeClasses = {
    small: 'scale-50',
    default: 'scale-100',
    large: 'scale-150'
  };

  return (
    <div className={`loadingspinner ${sizeClasses[size]} ${className}`}>
      <div id="square1"></div>
      <div id="square2"></div>
      <div id="square3"></div>
      <div id="square4"></div>
      <div id="square5"></div>
    </div>
  );
};

export default LoadingSpinner;
