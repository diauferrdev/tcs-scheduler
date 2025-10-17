import { useEffect } from 'react';

interface SEOProps {
  title?: string;
  description?: string;
  image?: string;
  url?: string;
  type?: 'website' | 'article' | 'profile';
  keywords?: string;
  author?: string;
  noindex?: boolean;
}

/**
 * SEO Component - Dynamically updates meta tags for better SEO and social sharing
 *
 * Usage:
 * <SEO
 *   title="Your Page Title"
 *   description="Your page description"
 *   image="https://yoursite.com/image.jpg"
 * />
 */
export default function SEO({
  title = 'TCS PacePort Scheduler',
  description = 'Schedule your visit to TCS PacePort São Paulo - Enterprise scheduling system for office visits with digital access badges',
  image = `${window.location.origin}/og-image.svg`,
  url = window.location.href,
  type = 'website',
  keywords = 'TCS, PacePort, Scheduler, São Paulo, Booking, Visit Scheduling, Access Badge',
  author = 'TCS PacePort',
  noindex = false,
}: SEOProps) {
  useEffect(() => {
    // Update document title
    document.title = title;

    // Helper function to update or create meta tag
    const updateMetaTag = (property: string, content: string, isProperty = false) => {
      const attribute = isProperty ? 'property' : 'name';
      let element = document.querySelector(`meta[${attribute}="${property}"]`);

      if (!element) {
        element = document.createElement('meta');
        element.setAttribute(attribute, property);
        document.head.appendChild(element);
      }

      element.setAttribute('content', content);
    };

    // Update basic meta tags
    updateMetaTag('title', title);
    updateMetaTag('description', description);
    updateMetaTag('keywords', keywords);
    updateMetaTag('author', author);
    updateMetaTag('robots', noindex ? 'noindex, nofollow' : 'index, follow');

    // Update canonical URL
    let canonical = document.querySelector('link[rel="canonical"]') as HTMLLinkElement;
    if (!canonical) {
      canonical = document.createElement('link');
      canonical.rel = 'canonical';
      document.head.appendChild(canonical);
    }
    canonical.href = url;

    // Update Open Graph tags
    updateMetaTag('og:type', type, true);
    updateMetaTag('og:url', url, true);
    updateMetaTag('og:title', title, true);
    updateMetaTag('og:description', description, true);
    updateMetaTag('og:image', image, true);
    updateMetaTag('og:image:alt', title, true);

    // Update Twitter Card tags
    updateMetaTag('twitter:card', 'summary_large_image');
    updateMetaTag('twitter:url', url);
    updateMetaTag('twitter:title', title);
    updateMetaTag('twitter:description', description);
    updateMetaTag('twitter:image', image);
    updateMetaTag('twitter:image:alt', title);
  }, [title, description, image, url, type, keywords, author, noindex]);

  return null; // This component doesn't render anything
}
