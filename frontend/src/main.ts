import './style.css';
import { initApp } from './app.ts';

const root = document.querySelector<HTMLDivElement>('#app')!;
initApp(root);
