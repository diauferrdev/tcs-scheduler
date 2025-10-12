import { useEffect } from 'react';
import { driver } from 'driver.js';
import 'driver.js/dist/driver.css';
import '../styles/tour.css';

interface TourGuideProps {
  onComplete?: () => void;
}

const TOUR_STORAGE_KEY = 'tcs-paceport-tour-completed';

export const useTourGuide = () => {
  const startTour = () => {
    const driverObj = driver({
      showProgress: true,
      showButtons: ['next', 'previous', 'close'],
      popoverClass: 'tcs-tour-popover',
      progressText: '{{current}} of {{total}}',
      nextBtnText: 'Next →',
      prevBtnText: '← Previous',
      doneBtnText: 'Got it!',
      steps: [
        {
          element: '[data-tour="calendar-grid"]',
          popover: {
            title: 'Welcome to the Booking Calendar',
            description: 'This is your scheduling calendar. Click on any available day to book your visit to TCS PacePort São Paulo.',
            side: 'bottom',
            align: 'center'
          }
        },
        {
          element: '[data-tour="legend"]',
          popover: {
            title: 'Understanding Availability',
            description: 'Use the legend to understand slot availability:<br/><br/><strong style="color: #22c55e;">● Green</strong>: Fully available<br/><strong style="color: #eab308;">● Yellow</strong>: Partially booked<br/><strong style="color: #ef4444;">● Red</strong>: Fully booked',
            side: 'left',
            align: 'start'
          }
        },
        {
          element: '[data-tour="month-nav"]',
          popover: {
            title: 'Navigate Months',
            description: 'Use these arrows to browse through different months and find the perfect date for your visit.',
            side: 'bottom',
            align: 'center'
          }
        },
        {
          popover: {
            title: 'Ready to Schedule!',
            description: 'Click on any available green or yellow day to select a time slot and complete your booking. We look forward to seeing you at TCS PacePort!',
          }
        }
      ],
      onDestroyStarted: () => {
        if (driverObj.hasNextStep()) {
          return;
        }
        // Mark tour as completed
        localStorage.setItem(TOUR_STORAGE_KEY, 'true');
        driverObj.destroy();
      }
    });

    driverObj.drive();
  };

  const shouldShowTour = () => {
    return !localStorage.getItem(TOUR_STORAGE_KEY);
  };

  const resetTour = () => {
    localStorage.removeItem(TOUR_STORAGE_KEY);
  };

  return { startTour, shouldShowTour, resetTour };
};
