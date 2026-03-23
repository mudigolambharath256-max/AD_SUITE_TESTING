import React from 'react';

const SvgIcon = ({ 
  name, 
  size = 24, 
  className = '', 
  fill = 'currentColor',
  ...props 
}) => {
  const getIconPath = (iconName) => {
    const iconMap = {
      'surveillance-defense': '/svg/surveillance-defense-svgrepo-com.svg',
      'safe-and-stable': '/svg/safe-and-stable-svgrepo-com.svg',
      'ddos-protection': '/svg/ddos-protection-svgrepo-com.svg',
      'data-analysis': '/svg/data-analysis-svgrepo-com.svg',
      '7x24h': '/svg/7x24h-svgrepo-com.svg',
      'all-covered': '/svg/all-covered-svgrepo-com.svg',
      'cloud-backup': '/svg/cloud-backup-svgrepo-com.svg',
      'system-settings': '/svg/system-settings-svgrepo-com.svg',
      'api-interface': '/svg/api-interface-svgrepo-com.svg',
      'availability': '/svg/availability-svgrepo-com.svg',
      'mobile-app': '/svg/mobile-app-svgrepo-com.svg',
      'port-detection': '/svg/port-detection-svgrepo-com.svg',
      'multiple-defenses': '/svg/multiple-defenses-svgrepo-com.svg',
      'host-record': '/svg/host-record-svgrepo-com.svg',
      'flexible-access': '/svg/flexible-access-svgrepo-com.svg',
      'interface-control': '/svg/interface-control-svgrepo-com.svg',
      'intelligent-positioning': '/svg/intelligent-positioning-svgrepo-com.svg',
      'cloud-acceleration': '/svg/cloud-acceleration-svgrepo-com.svg',
      'com-mac-old': '/svg/com-mac-old-svgrepo-com.svg',
      'mail-reception': '/svg/mail-reception-svgrepo-com.svg',
      'recursive-server': '/svg/recursive-server-svgrepo-com.svg'
    };
    return iconMap[iconName];
  };

  const iconPath = getIconPath(name);
  
  if (!iconPath) {
    console.warn(`Icon "${name}" not found`);
    return null;
  }

  return (
    <div 
      style={{ 
        width: `${size}px`, 
        height: `${size}px`,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}
      className={className}
      {...props}
    >
      <img
        src={iconPath}
        alt={`${name} icon`}
        style={{
          width: '100%',
          height: '100%',
          fill: fill,
          color: fill
        }}
        className={`${className} transition-all duration-200`}
      />
    </div>
  );
};

export default SvgIcon;
