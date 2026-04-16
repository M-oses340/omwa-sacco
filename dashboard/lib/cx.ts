// Shared Tailwind class strings for consistent dark mode
export const card  = 'bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-xl shadow-sm'
export const thead = 'bg-gray-50 dark:bg-gray-800 text-gray-500 dark:text-gray-400 text-xs uppercase'
export const tbody = 'divide-y divide-gray-50 dark:divide-gray-800'
export const tr    = 'hover:bg-gray-50 dark:hover:bg-gray-800/60'
export const th    = 'px-4 py-3 text-left'
export const td    = 'px-4 py-3'
export const input = 'border dark:border-gray-700 rounded-lg px-3 py-1.5 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500'
export const inputLg = 'border dark:border-gray-700 rounded-lg px-3 py-2 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500'
export const select = 'border dark:border-gray-700 rounded-lg px-3 py-1.5 text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-green-500'
export const badge = (status: string) => {
  if (status === 'completed' || status === 'active')
    return 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400'
  if (status === 'pending')
    return 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-400'
  return 'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-400'
}
